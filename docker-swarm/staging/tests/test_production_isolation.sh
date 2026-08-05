#!/bin/sh
# test_production_isolation.sh - Test that production resources are never targeted
# shellcheck disable=SC1091,SC2034

. ../scripts/lib.sh

SCRIPT_DIR="$(cd ../scripts && pwd -P)"
STAGING_DIR="$(cd .. && pwd -P)"

# ── Test 1: Stack name is 'staging' ─────────────────────────────────
echo "  Test 1: Stack name is 'staging'"
[ "${STACK_NAME}" = "staging" ] || {
    echo "  FAIL: STACK_NAME is '${STACK_NAME}', expected 'staging'"
    exit 1
}
echo "  PASS: Stack name is 'staging'"

# ── Test 2: Stack file does not reference production ────────────────
echo "  Test 2: Stack file does not reference production"
stack_yml="${STAGING_DIR}/stack.yml"
[ -f "${stack_yml}" ] || { echo "  FAIL: stack.yml not found"; exit 1; }

# Check for production-related terms
for term in production prod production_ production-; do
    if grep -qi "${term}" "${stack_yml}" 2>/dev/null; then
        # Only fail if it's not a comment or example
        if ! grep -q "#.*${term}" "${stack_yml}" 2>/dev/null; then
            echo "  FAIL: stack.yml contains production reference: ${term}"
            exit 1
        fi
    fi
done
echo "  PASS: Stack file does not reference production"

# ── Test 3: Scripts do not reference production stack names ──────────
echo "  Test 3: Scripts do not reference production stack names"
for script in "${SCRIPT_DIR}"/*.sh; do
    [ -f "${script}" ] || continue
    basename=$(basename "${script}")
    # Skip lib.sh which defines STACK_NAME
    [ "${basename}" = "lib.sh" ] && continue

    # Check for hardcoded production stack names
    while IFS= read -r line; do
        # Skip comments
        case "${line}" in
            \#*) continue ;;
        esac
        # Check for production stack references (not in comments or strings)
        case "${line}" in
            *production*)
                echo "  FAIL: ${basename} contains 'production'"
                exit 1
                ;;
            *prod_*)
                echo "  FAIL: ${basename} contains 'prod_'"
                exit 1
                ;;
        esac
    done < "${script}"
done
echo "  PASS: Scripts do not reference production"

# ── Test 4: Deploy manifest does not reference production ───────────
echo "  Test 4: Deploy manifest does not reference production"
manifest="${STAGING_DIR}/deploy-manifest.yml"
[ -f "${manifest}" ] || { echo "  FAIL: deploy-manifest.yml not found"; exit 1; }
if grep -qi 'production\|prod:' "${manifest}" 2>/dev/null; then
    echo "  FAIL: deploy-manifest.yml contains production reference"
    exit 1
fi
echo "  PASS: Deploy manifest does not reference production"

# ── Test 5: Systemd units reference staging only ────────────────────
echo "  Test 5: Systemd units reference staging only"
for unit in "${STAGING_DIR}/systemd/"*.service "${STAGING_DIR}/systemd/"*.timer; do
    [ -f "${unit}" ] || continue
    if grep -qi 'production\|prod ' "${unit}" 2>/dev/null; then
        echo "  FAIL: ${unit} contains production reference"
        exit 1
    fi
done
echo "  PASS: Systemd units reference staging only"

# ── Test 6: active GitHub Actions workflows do not target production ─
echo "  Test 6: GitHub Actions workflows do not target production"
PORTFOLIO_ROOT="$(cd ../../.. && pwd -P)"
for workflow in "${PORTFOLIO_ROOT}/github-actions/workflows/"*.yml; do
    [ -f "${workflow}" ] || continue
    if grep -qi 'production\|prod:' "${workflow}" 2>/dev/null; then
        echo "  FAIL: $(basename "${workflow}") contains production reference"
        exit 1
    fi
done
echo "  PASS: GitHub Actions workflows do not target production"

exit 0
