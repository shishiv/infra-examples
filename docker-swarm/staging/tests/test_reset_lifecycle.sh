#!/bin/sh
# test_reset_lifecycle.sh - synthetic reset preserves lifecycle, TTL, and fails safe
# shellcheck disable=SC1091,SC2034

. ./fixtures/mock-docker.sh

SCRIPTS_DIR="$(cd ../scripts && pwd -P)"
RUNTIME_DIR=$(mktemp -d)
STAGING_RUNTIME_DIR="${RUNTIME_DIR}"
STAGING_LOCK_DIR="${RUNTIME_DIR}/lock"
export STAGING_RUNTIME_DIR STAGING_LOCK_DIR
trap 'rm -rf "${RUNTIME_DIR}"' EXIT

. ../scripts/lib.sh

fail() { echo "  FAIL: $1"; mock_docker_teardown; exit 1; }

# $1 = pre-reset state, $2 = pre-reset TTL expiry (empty for none)
prepare() {
    mock_docker_setup
    cp fixtures/valid-manifest.yml "${ACTIVE_MANIFEST}"
    mock_docker_set_stacks "${STACK_NAME}"
    mock_docker_set_services \
        "${STACK_NAME}_paused-html" \
        "${STACK_NAME}_sample-web" \
        "${STACK_NAME}_sample-api" \
        "${STACK_NAME}_worker-sidecar" \
        "${STACK_NAME}_dashboard-web" \
        "${STACK_NAME}_sample-service"
    printf '%s\n' "$1" > "${STAGING_STATE_FILE}"
    if [ -n "$2" ]; then printf '%d\n' "$2" > "${TTL_FILE}"; else rm -f "${TTL_FILE}"; fi
}

# ── Test 1: a paused environment is not un-paused ───────────────────
echo "  Test 1: Reset of a paused environment stays paused"
prepare paused ""
REGISTRY_TOKEN=fixture "${SCRIPTS_DIR}/reset-synthetic.sh" >/dev/null 2>&1 || fail "reset failed"
grep -qx paused "${STAGING_STATE_FILE}" || fail "reset un-paused a paused environment"
[ -f "${TTL_FILE}" ] && fail "reset started a TTL clock on a paused environment"
mock_docker_get_calls | grep -q "docker service scale ${STACK_NAME}_sample-api=0" \
    || fail "application services were not scaled back to zero"
mock_docker_teardown
echo "  PASS: paused stays paused with no new TTL"

# ── Test 2: an active environment keeps its remaining TTL ───────────
echo "  Test 2: Reset of an active environment preserves the remaining TTL"
expiry=$(( $(date +%s) + 7200 ))
prepare active "${expiry}"
REGISTRY_TOKEN=fixture "${SCRIPTS_DIR}/reset-synthetic.sh" >/dev/null 2>&1 || fail "reset failed"
grep -qx active "${STAGING_STATE_FILE}" || fail "reset paused an active environment"
[ "$(cat "${TTL_FILE}")" = "${expiry}" ] || fail "reset replaced the remaining TTL with a fresh one"
REGISTRY_TOKEN=fixture "${SCRIPTS_DIR}/reset-synthetic.sh" >/dev/null 2>&1 || fail "second reset failed"
grep -qx active "${STAGING_STATE_FILE}" || fail "second reset changed the lifecycle"
[ "$(cat "${TTL_FILE}")" = "${expiry}" ] || fail "second reset extended the TTL"
mock_docker_teardown
echo "  PASS: repeated resets keep the same active lifecycle and expiry"

# ── Test 3: an expired environment ends stopped ─────────────────────
echo "  Test 3: Reset of an expired environment ends paused"
prepare active "$(( $(date +%s) - 60 ))"
REGISTRY_TOKEN=fixture "${SCRIPTS_DIR}/reset-synthetic.sh" >/dev/null 2>&1 || fail "reset failed"
grep -qx paused "${STAGING_STATE_FILE}" || fail "reset kept an expired environment active"
[ -f "${TTL_FILE}" ] && fail "reset left a TTL on a stopped environment"
mock_docker_teardown
echo "  PASS: an expired environment is not revived by a reset"

# ── Test 4: activation is explicit ──────────────────────────────────
echo "  Test 4: --activate starts staging with a fresh TTL"
prepare paused ""
REGISTRY_TOKEN=fixture "${SCRIPTS_DIR}/reset-synthetic.sh" --activate >/dev/null 2>&1 || fail "reset --activate failed"
grep -qx active "${STAGING_STATE_FILE}" || fail "--activate did not activate staging"
remaining=$(staging_ttl_remaining)
[ "${remaining}" -gt 3600 ] || fail "--activate did not write a fresh TTL"
mock_docker_teardown
echo "  PASS: --activate is the only path that grants a fresh TTL"

# ── Test 5: an unreachable daemon changes nothing ───────────────────
echo "  Test 5: Unreachable Docker daemon leaves the lifecycle untouched"
expiry=$(( $(date +%s) + 7200 ))
prepare active "${expiry}"
mock_docker_set_info_fail
if REGISTRY_TOKEN=fixture "${SCRIPTS_DIR}/reset-synthetic.sh" >/dev/null 2>&1; then
    fail "reset reported success with an unreachable daemon"
fi
grep -qx active "${STAGING_STATE_FILE}" || fail "a failed reset changed the state"
[ "$(cat "${TTL_FILE}")" = "${expiry}" ] || fail "a failed reset changed the TTL"
mock_docker_get_calls | grep -q 'docker stack rm' && fail "a failed reset still removed the stack"
mock_docker_teardown
echo "  PASS: a failed reset leaves state and TTL unchanged"

# ── Test 6: an unknown flag is refused before anything is touched ───
echo "  Test 6: Unknown flag is refused"
prepare active "${expiry}"
if REGISTRY_TOKEN=fixture "${SCRIPTS_DIR}/reset-synthetic.sh" --activate-now >/dev/null 2>&1; then
    fail "reset accepted an unknown flag"
fi
grep -qx active "${STAGING_STATE_FILE}" || fail "a refused reset changed the state"
mock_docker_get_calls | grep -q 'docker stack rm' && fail "a refused reset still removed the stack"
mock_docker_teardown
echo "  PASS: an unknown flag is refused without touching staging"

# ── Test 7: a failed recreate never records an unconfirmed pause ─────
echo "  Test 7: Start failure after the stack is recreated ends in a confirmed stop"
prepare paused ""
if MOCK_HTTP_STATUS=503 REGISTRY_TOKEN=fixture "${SCRIPTS_DIR}/reset-synthetic.sh" >/dev/null 2>&1; then
    fail "reset reported success despite a failing smoke test"
fi
calls=$(mock_docker_get_calls)
printf '%s\n' "${calls}" | grep -q 'docker stack deploy' || fail "the stack was never recreated, so the failure window was not exercised"
printf '%s\n' "${calls}" | grep -q "docker service scale ${STACK_NAME}_sample-api=0" \
    || fail "paused was recorded without stopping the recreated application services"
grep -qx paused "${STAGING_STATE_FILE}" || fail "a confirmed stop did not record paused"
[ -f "${TTL_FILE}" ] && fail "a failed reset left a TTL on a stopped environment"
mock_docker_teardown
echo "  PASS: a failed recreate stops the stack before recording paused"

# ── Test 8: a failed recreate keeps the pre-reset active lifecycle ───
echo "  Test 8: Start failure preserves an active environment's remaining TTL"
expiry=$(( $(date +%s) + 7200 ))
prepare active "${expiry}"
if MOCK_HTTP_STATUS=503 REGISTRY_TOKEN=fixture "${SCRIPTS_DIR}/reset-synthetic.sh" >/dev/null 2>&1; then
    fail "reset reported success despite a failing smoke test"
fi
grep -qx active "${STAGING_STATE_FILE}" || fail "a failed reset recorded paused over a running stack"
[ "$(cat "${TTL_FILE}")" = "${expiry}" ] || fail "a failed reset did not restore the remaining TTL"
mock_docker_teardown
echo "  PASS: a failed recreate restores the pre-reset lifecycle and TTL"

# ── Test 9: an unconfirmed stop stays retryable ─────────────────────
echo "  Test 9: Stop failure during restore leaves staging active for the retry"
prepare paused ""
mock_docker_set_scale_fail
if REGISTRY_TOKEN=fixture "${SCRIPTS_DIR}/reset-synthetic.sh" >/dev/null 2>&1; then
    fail "reset reported success despite a failing scale"
fi
mock_docker_get_calls | grep -q "docker service scale ${STACK_NAME}_sample-api=0" \
    || fail "the restore never attempted to stop the recreated services"
grep -qx active "${STAGING_STATE_FILE}" \
    || fail "an unconfirmed stop recorded paused, disabling the expiry retry"
[ -f "${TTL_FILE}" ] && fail "an unconfirmed stop left a TTL that delays the retry"
mock_docker_teardown
echo "  PASS: an unconfirmed stop keeps staging active and retryable"

# ── Test 10: an interrupt never mutates staging outside the lock ─────
echo "  Test 10: An interrupted reset restores the lifecycle under its own lock"
prepare paused ""
if REGISTRY_TOKEN=fixture sh -c 'printf "%s\n" $$ > "$1"; shift; exec "$@"' \
        _ "$(mock_docker_signal_pid_file)" "${SCRIPTS_DIR}/reset-synthetic.sh" >/dev/null 2>&1; then
    fail "an interrupted reset reported success"
fi
lock_calls=$(mock_docker_get_lock_calls)
printf '%s\n' "${lock_calls}" | grep -qx "held docker service scale ${STACK_NAME}_sample-api=0" \
    || fail "the interrupt released the lock before the lifecycle restore ran"
printf '%s\n' "${lock_calls}" | grep -qE '^free docker (stack (rm|deploy)|service scale)' \
    && fail "an interrupted reset mutated staging with no lock held"
grep -qx paused "${STAGING_STATE_FILE}" || fail "an interrupted reset did not restore the paused lifecycle"
[ -f "${TTL_FILE}" ] && fail "an interrupted reset left a TTL on a stopped environment"
[ -d "${STAGING_LOCK_DIR}" ] && fail "the interrupted reset never released its lock"
mock_docker_teardown
echo "  PASS: an interrupt keeps the lock until the fail-safe restore completes"

# ── Test 11: a lock is only ever released by its owner ──────────────
echo "  Test 11: lock_release respects the recorded owner"
mkdir -p "${STAGING_LOCK_DIR}"
printf '%d\n' 999999 > "${STAGING_LOCK_DIR}/owner"
lock_release
[ -d "${STAGING_LOCK_DIR}" ] || fail "lock_release removed a lock held by another operation"
printf '%d\n' "$$" > "${STAGING_LOCK_DIR}/owner"
lock_release
[ -d "${STAGING_LOCK_DIR}" ] && fail "lock_release did not remove this shell's own lock"
echo "  PASS: only the recording owner can release the staging lock"

exit 0
