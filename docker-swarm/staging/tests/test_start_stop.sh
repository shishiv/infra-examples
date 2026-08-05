#!/bin/sh
# test_start_stop.sh - Test start and stop commands
# shellcheck disable=SC1091,SC2034

. ./fixtures/mock-docker.sh
. ../scripts/lib.sh

# Override SCRIPT_DIR to point to actual scripts, STAGING_DIR to use test fixtures
SCRIPT_DIR="$(cd ../scripts && pwd -P)"
STAGING_DIR="$(cd ./fixtures && pwd -P)"
RUNTIME_DIR=$(mktemp -d)
STAGING_RUNTIME_DIR="${RUNTIME_DIR}"
STAGING_LOCK_DIR="${RUNTIME_DIR}/lock"
export STAGING_RUNTIME_DIR STAGING_LOCK_DIR
MANIFEST_DIR="${STAGING_DIR}"
TTL_FILE="${RUNTIME_DIR}/.staging-ttl"
STAGING_STATE_FILE="${RUNTIME_DIR}/.staging-state"
ACTIVE_MANIFEST="${RUNTIME_DIR}/.active-manifest.yml"

# Clean up any leftover state
rm -f "${TTL_FILE}" "${STAGING_STATE_FILE}" "${ACTIVE_MANIFEST}"

mock_docker_setup
trap 'mock_docker_teardown; rm -rf "${RUNTIME_DIR}"' EXIT

# ── Test 1: Start staging ──────────────────────────────────────────
echo "  Test 1: Start staging with valid manifest"
REGISTRY_TOKEN=fixture "${SCRIPT_DIR}/start.sh" "${STAGING_DIR}/valid-manifest.yml" 2>&1 || {
    echo "  FAIL: start.sh exited with error"
    exit 1
}

# Verify state
[ -f "${STAGING_STATE_FILE}" ] || { echo "  FAIL: state file not created"; exit 1; }
grep -q 'active' "${STAGING_STATE_FILE}" || { echo "  FAIL: state is not active"; exit 1; }
[ -f "${ACTIVE_MANIFEST}" ] || { echo "  FAIL: direct start did not record active manifest"; exit 1; }

# Verify TTL
[ -f "${TTL_FILE}" ] || { echo "  FAIL: TTL file not created"; exit 1; }
ttl=$(cat "${TTL_FILE}")
[ "${ttl}" -gt 0 ] || { echo "  FAIL: TTL not set"; exit 1; }

echo "  PASS: start.sh completed successfully"

# ── Test 2: Stop staging ───────────────────────────────────────────
echo "  Test 2: Stop staging"
"${SCRIPT_DIR}/stop.sh" 2>&1 || {
    echo "  FAIL: stop.sh exited with error"
    exit 1
}

# Verify state
grep -q 'paused' "${STAGING_STATE_FILE}" || { echo "  FAIL: state is not paused"; exit 1; }

# Verify TTL cleared
[ -f "${TTL_FILE}" ] && { echo "  FAIL: TTL file should be cleared"; exit 1; }

echo "  PASS: stop.sh completed successfully"

# ── Test 3: Start idempotent (already stopped) ──────────────────────
echo "  Test 3: Start again from recorded active manifest (idempotent)"
REGISTRY_TOKEN=fixture "${SCRIPT_DIR}/start.sh" 2>&1 || {
    echo "  FAIL: idempotent start failed"
    exit 1
}
grep -q 'active' "${STAGING_STATE_FILE}" || { echo "  FAIL: state is not active after second start"; exit 1; }
echo "  PASS: idempotent start works"

# ── Test 4: Stop idempotent (already stopped) ───────────────────────
echo "  Test 4: Stop again (idempotent)"
"${SCRIPT_DIR}/stop.sh" 2>&1 || {
    echo "  FAIL: idempotent stop failed"
    exit 1
}
grep -q 'paused' "${STAGING_STATE_FILE}" || { echo "  FAIL: state is not paused after second stop"; exit 1; }
echo "  PASS: idempotent stop works"

exit 0
