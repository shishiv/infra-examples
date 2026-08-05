#!/bin/sh
# test_expiry.sh - Test TTL expiry and extend functions
# shellcheck disable=SC1091,SC2034

. ./fixtures/mock-docker.sh
. ../scripts/lib.sh

SCRIPT_DIR="$(cd ../scripts && pwd -P)"
STAGING_DIR="$(cd ./fixtures && pwd -P)"
MANIFEST_DIR="${STAGING_DIR}"
TTL_FILE="${STAGING_DIR}/.staging-ttl"
STAGING_STATE_FILE="${STAGING_DIR}/.staging-state"

rm -f "${TTL_FILE}" "${STAGING_STATE_FILE}"

mock_docker_setup
trap 'mock_docker_teardown; rm -f "${TTL_FILE}" "${STAGING_STATE_FILE}"' EXIT

# ── Test 1: staging_ttl_remaining when no TTL file ──────────────────
echo "  Test 1: TTL remaining with no TTL file"
remaining=$(staging_ttl_remaining)
[ "${remaining}" = "0" ] || { echo "  FAIL: expected 0, got ${remaining}"; exit 1; }
echo "  PASS: TTL remaining is 0 when no TTL file"

# ── Test 2: is_staging_active when not active ───────────────────────
echo "  Test 2: is_staging_active when not active"
is_staging_active && { echo "  FAIL: should not be active"; exit 1; }
echo "  PASS: is_staging_active returns false"

# ── Test 3: write_state and is_staging_active ──────────────────────
echo "  Test 3: write_state and is_staging_active"
write_state "active"
is_staging_active || { echo "  FAIL: should be active after write_state"; exit 1; }
echo "  PASS: is_staging_active returns true after write_state"

# ── Test 4: write_ttl and staging_ttl_remaining ─────────────────────
echo "  Test 4: write_ttl and staging_ttl_remaining"
write_ttl 4
remaining=$(staging_ttl_remaining)
[ "${remaining}" -gt 0 ] || { echo "  FAIL: TTL should be positive"; exit 1; }
echo "  PASS: TTL remaining is ${remaining}s"

# ── Test 5: clear_ttl ──────────────────────────────────────────────
echo "  Test 5: clear_ttl"
clear_ttl
[ -f "${TTL_FILE}" ] && { echo "  FAIL: TTL file should be cleared"; exit 1; }
remaining=$(staging_ttl_remaining)
[ "${remaining}" = "0" ] || { echo "  FAIL: expected 0 after clear, got ${remaining}"; exit 1; }
echo "  PASS: clear_ttl works"

# ── Test 6: write_state paused ──────────────────────────────────────
echo "  Test 6: write_state paused"
write_state "paused"
is_staging_active && { echo "  FAIL: should not be active after paused"; exit 1; }
grep -q 'paused' "${STAGING_STATE_FILE}" || { echo "  FAIL: state should be paused"; exit 1; }
echo "  PASS: write_state paused works"

exit 0
