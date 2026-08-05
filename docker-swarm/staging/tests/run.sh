#!/bin/sh
# run.sh - Run the infrastructure module test suite
# shellcheck disable=SC2034
#
# All tests use mocked Docker commands - no root, Docker Swarm,
# network access, or live credentials required.
#
# Usage: ./run.sh [test_name ...]
#   If no test names given, runs all tests.

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
TESTS_DIR="${SCRIPT_DIR}"
PASS=0
FAIL=0
SKIP=0

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ── Test runner ────────────────────────────────────────────────────
run_test() {
    test_file="$1"
    test_name="$(basename "${test_file}" .sh)"

    if [ $# -gt 1 ]; then
        # Filter: only run specified tests
        found=0
    for t in "$@"; do
        case "${test_name}" in
            *"${t}"*) found=1 ;;
        esac
    done
    [ "${found}" -eq 1 ] || { SKIP=$(( SKIP + 1 )); return; }
    fi

    printf "${YELLOW}[TEST]${NC} %s ... " "${test_name}"

    # Run test in subshell
    if ( cd "${TESTS_DIR}" && \
         rm -rf /tmp/portfolio-infra-staging-lock && \
         sh "${test_file}" ); then
        printf '%bPASS%b\n' "${GREEN}" "${NC}"
        PASS=$(( PASS + 1 ))
    else
        printf '%bFAIL%b\n' "${RED}" "${NC}"
        FAIL=$(( FAIL + 1 ))
    fi
}

# ── Discover and run tests ─────────────────────────────────────────
echo "=== Infrastructure Module Test Suite ==="
echo ""

if [ $# -gt 0 ]; then
    echo "Running ${#} specific test(s)..."
else
    echo "Running all tests..."
fi
echo ""

for test_file in "${TESTS_DIR}"/test_*.sh; do
    [ -f "${test_file}" ] || continue
    run_test "${test_file}" "$@"
done

# ── Summary ─────────────────────────────────────────────────────────
echo ""
echo "=== Results ==="
echo "  Pass: ${PASS}"
echo "  Fail: ${FAIL}"
echo "  Skip: ${SKIP}"
echo ""

if [ "${FAIL}" -gt 0 ]; then
    echo "Some tests FAILED."
    exit 1
fi

echo "All tests passed."
exit 0
