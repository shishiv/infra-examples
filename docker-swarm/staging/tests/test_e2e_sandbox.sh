#!/bin/sh
# test_e2e_sandbox.sh - Test the isolated local E2E sandbox entrypoint
# shellcheck disable=SC2034

DOCKER_SWARM_ROOT="$(cd ../.. && pwd -P)"
PORTFOLIO_ROOT="$(cd ../../.. && pwd -P)"
TMP_ROOT="$(mktemp -d)"
OUTPUT_FILE="${TMP_ROOT}/output"

trap 'rm -rf "${TMP_ROOT}"' EXIT

printf '%s\n' '  Test 1: local E2E sandbox serves the paused-page contract'
if ! TMPDIR="${TMP_ROOT}" "${PORTFOLIO_ROOT}/bash-ops/e2e-sandbox.sh" --self-test >"${OUTPUT_FILE}" 2>&1; then
    cat "${OUTPUT_FILE}"
    echo '  FAIL: E2E sandbox self-test failed'
    exit 1
fi
grep -Fq 'E2E sandbox passed: loopback HTTP contract verified; staging stayed disabled.' "${OUTPUT_FILE}" || {
    cat "${OUTPUT_FILE}"
    echo '  FAIL: E2E sandbox did not print its success receipt'
    exit 1
}
echo '  PASS: E2E sandbox served the real paused-page artifact over loopback'

printf '%s\n' '  Test 2: self-test leaves no sandbox directory behind'
if find "${TMP_ROOT}" -mindepth 1 -maxdepth 1 -name 'infra-examples-e2e-sandbox.*' -print -quit | grep -q .; then
    echo '  FAIL: E2E sandbox left a temporary directory behind'
    exit 1
fi
echo '  PASS: E2E sandbox cleaned its temporary directory'

printf '%s\n' '  Test 3: self-test leaves the repository staging runtime untouched'
[ ! -e "${DOCKER_SWARM_ROOT}/staging/.staging-state" ] || { echo '  FAIL: repository staging state appeared'; exit 1; }
[ ! -e "${DOCKER_SWARM_ROOT}/staging/.staging-ttl" ] || { echo '  FAIL: repository staging TTL appeared'; exit 1; }
echo '  PASS: no staging runtime state was created'
