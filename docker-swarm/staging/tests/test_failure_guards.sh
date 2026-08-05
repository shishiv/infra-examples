#!/bin/sh
# test_failure_guards.sh - Test that docker failures abort and locks are shared
# shellcheck disable=SC1091,SC2034

. ./fixtures/mock-docker.sh
. ../scripts/lib.sh

SCRIPT_DIR="$(cd ../scripts && pwd -P)"
STAGING_DIR="$(cd ./fixtures && pwd -P)"
RUNTIME_DIR=$(mktemp -d)
STAGING_RUNTIME_DIR="${RUNTIME_DIR}"
STAGING_LOCK_DIR="${RUNTIME_DIR}/lock"
export STAGING_RUNTIME_DIR STAGING_LOCK_DIR
MANIFEST="${STAGING_DIR}/valid-manifest.yml"
# lib.sh derives these from the default runtime directory when it is sourced
# above, so every one of them is re-pointed at this run's temporary directory
# before any test runs. The lifecycle scripts read the exported
# STAGING_RUNTIME_DIR, so assertions and children then share one isolated path.
STAGING_STATE_FILE="${RUNTIME_DIR}/.staging-state"
TTL_FILE="${RUNTIME_DIR}/.staging-ttl"
ACTIVE_MANIFEST="${RUNTIME_DIR}/.active-manifest.yml"
MANIFEST_HISTORY_DIR="${RUNTIME_DIR}/.manifest-history"

trap 'rm -rf "${RUNTIME_DIR}"' EXIT

# ── Test 1: A failed pull aborts start.sh ───────────────────────────
echo "  Test 1: Failed docker pull aborts start"
mock_docker_setup
mock_docker_set_pull_fail
if REGISTRY_TOKEN=fixture "${SCRIPT_DIR}/start.sh" "${MANIFEST}" >/dev/null 2>&1; then
    echo "  FAIL: start.sh succeeded despite a failing docker pull"
    mock_docker_teardown
    exit 1
fi
[ -f "${STAGING_STATE_FILE}" ] && { echo "  FAIL: state recorded after a failed pull"; mock_docker_teardown; exit 1; }
mock_docker_teardown
echo "  PASS: failed pull aborts start"

# ── Test 2: A failed stack deploy aborts start.sh ───────────────────
echo "  Test 2: Failed stack deploy aborts start"
mock_docker_setup
mock_docker_set_deploy_fail
if REGISTRY_TOKEN=fixture "${SCRIPT_DIR}/start.sh" "${MANIFEST}" >/dev/null 2>&1; then
    echo "  FAIL: start.sh succeeded despite a failing stack deploy"
    mock_docker_teardown
    exit 1
fi
mock_docker_teardown
echo "  PASS: failed stack deploy aborts start"

# ── Test 3: A failed service scale aborts start.sh ──────────────────
echo "  Test 3: Failed service scale aborts start"
mock_docker_setup
mock_docker_set_scale_fail
if REGISTRY_TOKEN=fixture "${SCRIPT_DIR}/start.sh" "${MANIFEST}" >/dev/null 2>&1; then
    echo "  FAIL: start.sh succeeded despite a failing service scale"
    mock_docker_teardown
    exit 1
fi
mock_docker_teardown
echo "  PASS: failed service scale aborts start"

# ── Test 4: A failed registry login aborts start.sh ─────────────────
echo "  Test 4: Failed registry login aborts start"
mock_docker_setup
mock_docker_set_login_fail
if REGISTRY_TOKEN=fixture "${SCRIPT_DIR}/start.sh" "${MANIFEST}" >/dev/null 2>&1; then
    echo "  FAIL: start.sh succeeded despite a failing registry login"
    mock_docker_teardown
    exit 1
fi
mock_docker_teardown
echo "  PASS: failed registry login aborts start"

# ── Test 5: stop.sh honours a caller-held lock ──────────────────────
echo "  Test 5: stop.sh honours STAGING_LOCK_HELD"
mock_docker_setup
mkdir -p "${STAGING_LOCK_DIR}"
STAGING_LOCK_HELD=1 "${SCRIPT_DIR}/stop.sh" >/dev/null 2>&1 || {
    echo "  FAIL: stop.sh failed while the caller held the lock"
    mock_docker_teardown
    exit 1
}
[ -d "${STAGING_LOCK_DIR}" ] || {
    echo "  FAIL: stop.sh released a lock it does not own"
    mock_docker_teardown
    exit 1
}
rmdir "${STAGING_LOCK_DIR}"
mock_docker_teardown
echo "  PASS: stop.sh leaves a caller-held lock intact"

# ── Test 6: stop.sh still refuses a concurrent operation ────────────
echo "  Test 6: stop.sh refuses when another operation holds the lock"
mock_docker_setup
mkdir -p "${STAGING_LOCK_DIR}"
if "${SCRIPT_DIR}/stop.sh" >/dev/null 2>&1; then
    echo "  FAIL: stop.sh ran while another operation held the lock"
    mock_docker_teardown
    exit 1
fi
[ -d "${STAGING_LOCK_DIR}" ] || {
    echo "  FAIL: refused stop.sh removed the other operation's lock"
    mock_docker_teardown
    exit 1
}
rmdir "${STAGING_LOCK_DIR}"
mock_docker_teardown
echo "  PASS: concurrent stop is refused without clobbering the lock"

# ── Test 7: a failed scale-to-0 keeps the TTL retryable ─────────────
echo "  Test 7: Failed scale-to-0 leaves staging active for the expiry retry"
mock_docker_setup
mock_docker_set_stacks "${STACK_NAME}"
mock_docker_set_services \
    "${STACK_NAME}_paused-html" \
    "${STACK_NAME}_sample-web" \
    "${STACK_NAME}_sample-api" \
    "${STACK_NAME}_worker-sidecar" \
    "${STACK_NAME}_dashboard-web" \
    "${STACK_NAME}_sample-service"
mock_docker_set_scale_fail
printf 'active\n' > "${STAGING_STATE_FILE}"
printf '%d\n' 1 > "${TTL_FILE}"
if "${SCRIPT_DIR}/stop.sh" >/dev/null 2>&1; then
    echo "  FAIL: stop.sh reported success despite a failing scale-to-0"
    mock_docker_teardown
    exit 1
fi
grep -qx 'active' "${STAGING_STATE_FILE}" || {
    echo "  FAIL: failed stop marked staging paused, disabling the expiry retry"
    mock_docker_teardown
    exit 1
}
[ -f "${TTL_FILE}" ] || {
    echo "  FAIL: failed stop cleared the expired TTL"
    mock_docker_teardown
    exit 1
}
mock_docker_teardown
echo "  PASS: failed stop keeps staging active and the TTL expired"

# ── Test 8: check-expiry retries after a failed stop ────────────────
echo "  Test 8: check-expiry reports failure when stop fails"
mock_docker_setup
mock_docker_set_stacks "${STACK_NAME}"
mock_docker_set_services "${STACK_NAME}_paused-html" "${STACK_NAME}_sample-api"
mock_docker_set_scale_fail
printf 'active\n' > "${STAGING_STATE_FILE}"
printf '%d\n' 1 > "${TTL_FILE}"
if "${SCRIPT_DIR}/check-expiry.sh" >/dev/null 2>&1; then
    echo "  FAIL: check-expiry reported success despite a failing stop"
    mock_docker_teardown
    exit 1
fi
grep -qx 'active' "${STAGING_STATE_FILE}" || {
    echo "  FAIL: check-expiry left staging paused after a failed stop"
    mock_docker_teardown
    exit 1
}
mock_docker_teardown
echo "  PASS: check-expiry surfaces a failed stop and leaves staging retryable"

# ── Test 9: run_redacted never buffers output to disk ───────────────
echo "  Test 9: run_redacted leaves no un-redacted temp file"
probe_tmp=$(mktemp -d)
probe_out="${RUNTIME_DIR}/redacted-probe"
# The inner command inspects TMPDIR while run_redacted is still mid-flight, so
# any output buffered to disk is observable even though it would be cleaned up.
# shellcheck disable=SC2016  # TMPDIR must expand inside the probed command
TMPDIR="${probe_tmp}" run_redacted sh -c 'find "${TMPDIR}" -type f | wc -l; printf "%s%s%s\n" token ghp_ fixturevalue; exit 3' > "${probe_out}" 2>&1 && {
    echo "  FAIL: run_redacted lost a non-zero exit status"
    rm -rf "${probe_tmp}"
    exit 1
}
grep -q '\*\*\*REDACTED\*\*\*' "${probe_out}" || {
    echo "  FAIL: run_redacted did not redact its output"
    rm -rf "${probe_tmp}"
    exit 1
}
[ "$(head -n 1 "${probe_out}" | tr -d '[:space:]')" = "0" ] || {
    echo "  FAIL: run_redacted buffered un-redacted output to a file in TMPDIR"
    rm -rf "${probe_tmp}"
    exit 1
}
rm -rf "${probe_tmp}"
echo "  PASS: run_redacted redacts, preserves status, and touches no disk"

# ── Test 10: a failed stack query is not read as "stack absent" ─────
echo "  Test 10: Failed stack query does not record staging as paused"
mock_docker_setup
mock_docker_set_stack_ls_fail
printf 'active\n' > "${STAGING_STATE_FILE}"
printf '%d\n' 1 > "${TTL_FILE}"
if "${SCRIPT_DIR}/stop.sh" >/dev/null 2>&1; then
    echo "  FAIL: stop.sh reported success despite a failing stack query"
    mock_docker_teardown
    exit 1
fi
grep -qx 'active' "${STAGING_STATE_FILE}" || {
    echo "  FAIL: a failed stack query marked staging paused, disabling the expiry retry"
    mock_docker_teardown
    exit 1
}
[ -f "${TTL_FILE}" ] || {
    echo "  FAIL: a failed stack query cleared the expired TTL"
    mock_docker_teardown
    exit 1
}
mock_docker_teardown
echo "  PASS: failed stack query leaves staging active and retryable"

# ── Test 11: a failed service query aborts before any state write ───
echo "  Test 11: Failed service query does not record staging as paused"
mock_docker_setup
mock_docker_set_stacks "${STACK_NAME}"
mock_docker_set_service_ls_fail
printf 'active\n' > "${STAGING_STATE_FILE}"
printf '%d\n' 1 > "${TTL_FILE}"
if "${SCRIPT_DIR}/stop.sh" >/dev/null 2>&1; then
    echo "  FAIL: stop.sh reported success despite a failing service query"
    mock_docker_teardown
    exit 1
fi
grep -qx 'active' "${STAGING_STATE_FILE}" || {
    echo "  FAIL: a failed service query marked staging paused"
    mock_docker_teardown
    exit 1
}
[ -f "${TTL_FILE}" ] || {
    echo "  FAIL: a failed service query cleared the expired TTL"
    mock_docker_teardown
    exit 1
}
mock_docker_teardown
echo "  PASS: failed service query leaves staging active and retryable"

# ── Test 12: an unreachable daemon aborts at require_docker ─────────
echo "  Test 12: Unreachable Docker daemon aborts before any state write"
mock_docker_setup
mock_docker_set_info_fail
printf 'active\n' > "${STAGING_STATE_FILE}"
printf '%d\n' 1 > "${TTL_FILE}"
if "${SCRIPT_DIR}/stop.sh" >/dev/null 2>&1; then
    echo "  FAIL: stop.sh reported success with an unreachable Docker daemon"
    mock_docker_teardown
    exit 1
fi
grep -qx 'active' "${STAGING_STATE_FILE}" || {
    echo "  FAIL: an unreachable daemon marked staging paused"
    mock_docker_teardown
    exit 1
}
if "${SCRIPT_DIR}/check-expiry.sh" >/dev/null 2>&1; then
    echo "  FAIL: check-expiry reported success with an unreachable Docker daemon"
    mock_docker_teardown
    exit 1
fi
grep -qx 'active' "${STAGING_STATE_FILE}" || {
    echo "  FAIL: check-expiry left staging paused after an unreachable daemon"
    mock_docker_teardown
    exit 1
}
mock_docker_teardown
echo "  PASS: unreachable daemon leaves staging active and retryable"

# ── Test 13: a direct start that fails after deploying stops the stack ──
echo "  Test 13: Failed direct start of a paused environment ends in a confirmed stop"
mock_docker_setup
printf 'paused\n' > "${STAGING_STATE_FILE}"
rm -f "${TTL_FILE}"
if MOCK_HTTP_STATUS=503 REGISTRY_TOKEN=fixture "${SCRIPT_DIR}/start.sh" "${MANIFEST}" >/dev/null 2>&1; then
    echo "  FAIL: start.sh succeeded despite a failing smoke test"
    mock_docker_teardown
    exit 1
fi
mock_docker_get_calls | grep -q '^docker stack deploy' || {
    echo "  FAIL: the start never deployed, so the failure window was not exercised"
    mock_docker_teardown
    exit 1
}
mock_docker_get_calls | grep -q "docker service scale ${STACK_NAME}_sample-api=0" || {
    echo "  FAIL: a failed start left the services it brought up running"
    mock_docker_teardown
    exit 1
}
grep -qx 'paused' "${STAGING_STATE_FILE}" || {
    echo "  FAIL: a failed start did not restore the paused lifecycle"
    mock_docker_teardown
    exit 1
}
[ -f "${TTL_FILE}" ] && {
    echo "  FAIL: a failed start left a TTL on a stopped environment"
    mock_docker_teardown
    exit 1
}
[ -d "${STAGING_LOCK_DIR}" ] && {
    echo "  FAIL: a failed start never released its lock"
    mock_docker_teardown
    exit 1
}
mock_docker_teardown
echo "  PASS: a failed direct start stops the stack it brought up"

# ── Test 14: a failed direct start keeps the remaining TTL ──────────
echo "  Test 14: Failed direct start of an active environment keeps its remaining TTL"
mock_docker_setup
cp "${MANIFEST}" "${ACTIVE_MANIFEST}"
expiry=$(( $(date +%s) + 7200 ))
printf 'active\n' > "${STAGING_STATE_FILE}"
printf '%d\n' "${expiry}" > "${TTL_FILE}"
if MOCK_HTTP_STATUS=503 REGISTRY_TOKEN=fixture "${SCRIPT_DIR}/start.sh" "${MANIFEST}" >/dev/null 2>&1; then
    echo "  FAIL: start.sh succeeded despite a failing smoke test"
    mock_docker_teardown
    exit 1
fi
[ "$(mock_docker_get_calls | grep -c '^docker stack deploy')" -eq 2 ] || {
    echo "  FAIL: the last active manifest was not redeployed exactly once"
    mock_docker_teardown
    exit 1
}
grep -qx 'active' "${STAGING_STATE_FILE}" || {
    echo "  FAIL: a failed start paused a running environment"
    mock_docker_teardown
    exit 1
}
[ "$(cat "${TTL_FILE}")" = "${expiry}" ] || {
    echo "  FAIL: a failed start replaced the remaining TTL"
    mock_docker_teardown
    exit 1
}
[ -d "${STAGING_LOCK_DIR}" ] && {
    echo "  FAIL: a failed start never released its lock"
    mock_docker_teardown
    exit 1
}
mock_docker_teardown
echo "  PASS: a failed direct start restores the active manifest and its TTL"

# ── Test 15: a confirmed stop really clears the isolated TTL ────────
# Positive control for every "[ -f ${TTL_FILE} ]" assertion above: it proves the
# path this file asserts on is the one the lifecycle scripts actually write.
echo "  Test 15: A confirmed stop clears the TTL this file asserts on"
mock_docker_setup
mock_docker_set_stacks "${STACK_NAME}"
mock_docker_set_services \
    "${STACK_NAME}_paused-html" \
    "${STACK_NAME}_sample-web" \
    "${STACK_NAME}_sample-api" \
    "${STACK_NAME}_worker-sidecar" \
    "${STACK_NAME}_dashboard-web" \
    "${STACK_NAME}_sample-service"
printf 'active\n' > "${STAGING_STATE_FILE}"
printf '%d\n' "$(( $(date +%s) + 3600 ))" > "${TTL_FILE}"
"${SCRIPT_DIR}/stop.sh" >/dev/null 2>&1 || {
    echo "  FAIL: stop.sh failed on a healthy stack"
    mock_docker_teardown
    exit 1
}
[ -f "${TTL_FILE}" ] && {
    echo "  FAIL: a confirmed stop left the TTL in place, so the TTL assertions prove nothing"
    mock_docker_teardown
    exit 1
}
grep -qx 'paused' "${STAGING_STATE_FILE}" || {
    echo "  FAIL: a confirmed stop did not record paused"
    mock_docker_teardown
    exit 1
}
mock_docker_teardown
echo "  PASS: the asserted TTL path is the one the scripts clear"

# ── Test 16: an interrupted direct start reconciles instead of exiting ──
echo "  Test 16: Interrupted direct start of a paused environment ends in a confirmed stop"
mock_docker_setup
printf 'paused\n' > "${STAGING_STATE_FILE}"
rm -f "${TTL_FILE}"
probe_tmp="${RUNTIME_DIR}/tmp-16"
mkdir -p "${probe_tmp}"
start_status=0
TMPDIR="${probe_tmp}" REGISTRY_TOKEN=fixture sh -c 'printf "%s\n" $$ > "$1"; shift; exec "$@"' \
    _ "$(mock_docker_signal_pid_file)" "${SCRIPT_DIR}/start.sh" "${MANIFEST}" >/dev/null 2>&1 || start_status=$?
[ "${start_status}" -ne 0 ] || {
    echo "  FAIL: an interrupted start reported success"
    mock_docker_teardown
    exit 1
}
[ "${start_status}" -ne 130 ] || {
    echo "  FAIL: an interrupted start exited from its signal handler without reconciling"
    mock_docker_teardown
    exit 1
}
mock_docker_get_calls | grep -q "docker service scale ${STACK_NAME}_sample-api=0" || {
    echo "  FAIL: an interrupted start left the services it brought up running"
    mock_docker_teardown
    exit 1
}
grep -qx 'paused' "${STAGING_STATE_FILE}" || {
    echo "  FAIL: an interrupted start did not restore the paused lifecycle"
    mock_docker_teardown
    exit 1
}
[ -f "${TTL_FILE}" ] && {
    echo "  FAIL: an interrupted start left a TTL on a stopped environment"
    mock_docker_teardown
    exit 1
}
[ -d "${STAGING_LOCK_DIR}" ] && {
    echo "  FAIL: an interrupted start never released its lock"
    mock_docker_teardown
    exit 1
}
[ "$(find "${probe_tmp}" -type f | wc -l)" -eq 0 ] || {
    echo "  FAIL: an interrupted start left a rendered stack file behind"
    mock_docker_teardown
    exit 1
}
running=$(ps -eo args= 2>/dev/null || true)
printf '%s\n' "${running}" | grep -q "${SCRIPT_DIR}/" && {
    echo "  FAIL: an interrupted start leaked a child process"
    mock_docker_teardown
    exit 1
}
mock_docker_get_lock_calls | grep -qE '^free docker (stack (rm|deploy)|service scale)' && {
    echo "  FAIL: an interrupted start mutated staging with no lock held"
    mock_docker_teardown
    exit 1
}
mock_docker_teardown
echo "  PASS: an interrupted direct start reconciles under its own lock"

# ── Test 17: an interrupted direct start keeps the remaining TTL ────
echo "  Test 17: Interrupted direct start of an active environment restores its remaining TTL"
mock_docker_setup
cp "${MANIFEST}" "${ACTIVE_MANIFEST}"
expiry=$(( $(date +%s) + 7200 ))
printf 'active\n' > "${STAGING_STATE_FILE}"
printf '%d\n' "${expiry}" > "${TTL_FILE}"
probe_tmp="${RUNTIME_DIR}/tmp-17"
mkdir -p "${probe_tmp}"
start_status=0
TMPDIR="${probe_tmp}" REGISTRY_TOKEN=fixture sh -c 'printf "%s\n" $$ > "$1"; shift; exec "$@"' \
    _ "$(mock_docker_signal_pid_file)" "${SCRIPT_DIR}/start.sh" "${MANIFEST}" >/dev/null 2>&1 || start_status=$?
[ "${start_status}" -ne 0 ] || {
    echo "  FAIL: an interrupted start reported success"
    mock_docker_teardown
    exit 1
}
[ "${start_status}" -ne 130 ] || {
    echo "  FAIL: an interrupted start exited from its signal handler without reconciling"
    mock_docker_teardown
    exit 1
}
[ "$(mock_docker_get_calls | grep -c '^docker stack deploy')" -eq 2 ] || {
    echo "  FAIL: the last active manifest was not redeployed exactly once"
    mock_docker_teardown
    exit 1
}
grep -qx 'active' "${STAGING_STATE_FILE}" || {
    echo "  FAIL: an interrupted start paused a running environment"
    mock_docker_teardown
    exit 1
}
[ "$(cat "${TTL_FILE}")" = "${expiry}" ] || {
    echo "  FAIL: an interrupted start replaced the remaining TTL"
    mock_docker_teardown
    exit 1
}
[ -d "${STAGING_LOCK_DIR}" ] && {
    echo "  FAIL: an interrupted start never released its lock"
    mock_docker_teardown
    exit 1
}
[ "$(find "${probe_tmp}" -type f | wc -l)" -eq 0 ] || {
    echo "  FAIL: an interrupted start left a rendered stack file behind"
    mock_docker_teardown
    exit 1
}
running=$(ps -eo args= 2>/dev/null || true)
printf '%s\n' "${running}" | grep -q "${SCRIPT_DIR}/" && {
    echo "  FAIL: an interrupted start leaked a child process"
    mock_docker_teardown
    exit 1
}
mock_docker_teardown
echo "  PASS: an interrupted direct start restores the active manifest and its TTL"

exit 0
