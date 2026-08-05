#!/bin/sh
# test_idempotency.sh - Test idempotent behavior of commands
# shellcheck disable=SC1091,SC2034

. ./fixtures/mock-docker.sh
. ../scripts/lib.sh

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

rm -f "${TTL_FILE}" "${STAGING_STATE_FILE}" "${ACTIVE_MANIFEST}"

mock_docker_setup
trap 'mock_docker_teardown; rm -rf "${RUNTIME_DIR}"' EXIT

# ── Test 1: Start twice (idempotent) ───────────────────────────────
echo "  Test 1: Start staging twice"
REGISTRY_TOKEN=fixture "${SCRIPT_DIR}/start.sh" "${STAGING_DIR}/valid-manifest.yml" 2>&1 || {
    echo "  FAIL: first start failed"
    exit 1
}

REGISTRY_TOKEN=fixture "${SCRIPT_DIR}/start.sh" "${STAGING_DIR}/valid-manifest.yml" 2>&1 || {
    echo "  FAIL: second start (idempotent) failed"
    exit 1
}

grep -q 'active' "${STAGING_STATE_FILE}" || { echo "  FAIL: state should be active"; exit 1; }
echo "  PASS: Start is idempotent"

# ── Test 2: Stop twice (idempotent) ─────────────────────────────────
echo "  Test 2: Stop staging twice"
"${SCRIPT_DIR}/stop.sh" 2>&1 || {
    echo "  FAIL: first stop failed"
    exit 1
}

"${SCRIPT_DIR}/stop.sh" 2>&1 || {
    echo "  FAIL: second stop (idempotent) failed"
    exit 1
}

grep -q 'paused' "${STAGING_STATE_FILE}" || { echo "  FAIL: state should be paused"; exit 1; }
echo "  PASS: Stop is idempotent"

# ── Test 3: Deploy same manifest twice ──────────────────────────────
echo "  Test 3: Deploy same manifest twice"
REGISTRY_TOKEN=fixture "${SCRIPT_DIR}/deploy.sh" "${STAGING_DIR}/valid-manifest.yml" 2>&1 || {
    echo "  FAIL: first deploy failed"
    exit 1
}

REGISTRY_TOKEN=fixture "${SCRIPT_DIR}/deploy.sh" "${STAGING_DIR}/valid-manifest.yml" 2>&1 || {
    echo "  FAIL: second deploy (idempotent) failed"
    exit 1
}
echo "  PASS: Deploy is idempotent"

# ── Test 4: Extend TTL twice ────────────────────────────────────────
echo "  Test 4: Extend TTL twice"
"${SCRIPT_DIR}/extend-ttl.sh" 2 2>&1 || {
    echo "  FAIL: first extend failed"
    exit 1
}

"${SCRIPT_DIR}/extend-ttl.sh" 4 2>&1 || {
    echo "  FAIL: second extend failed"
    exit 1
}

ttl_remaining=$(staging_ttl_remaining)
[ "${ttl_remaining}" -gt 3600 ] || { echo "  FAIL: TTL should be > 1 hour"; exit 1; }
echo "  PASS: Extend TTL is idempotent"

exit 0
