#!/bin/sh
# test_paused_domain.sh - Test that paused domain returns explicit response
# shellcheck disable=SC1091,SC2034

. ../scripts/lib.sh

# ── Test 1: Paused HTML page exists and has expected content ────────
echo "  Test 1: Paused HTML page exists"
paused_html="${STAGING_DIR}/paused-html/index.html"
[ -f "${paused_html}" ] || { echo "  FAIL: paused-html/index.html not found"; exit 1; }
echo "  PASS: paused HTML page exists"

# ── Test 2: Paused page contains expected text ───────────────────────
echo "  Test 2: Paused page contains expected text"
grep -q 'Paused' "${paused_html}" || { echo "  FAIL: paused page missing 'Paused' text"; exit 1; }
grep -q 'Staging Environment' "${paused_html}" || { echo "  FAIL: paused page missing title"; exit 1; }
echo "  PASS: paused page contains expected text"

# ── Test 3: Paused page has X-Staging-State header in nginx config ──
echo "  Test 3: Paused page nginx config has staging state header"
nginx_conf="${STAGING_DIR}/paused-html/nginx.conf"
[ -f "${nginx_conf}" ] || { echo "  FAIL: nginx.conf not found"; exit 1; }
grep -q 'X-Staging-State' "${nginx_conf}" || { echo "  FAIL: nginx.conf missing X-Staging-State header"; exit 1; }
echo "  PASS: nginx config has staging state header"

# ── Test 4: Stack.yml has paused-html service with Traefik labels ───
echo "  Test 4: Stack has paused-html service with Traefik labels"
stack_yml="${STAGING_DIR}/stack.yml"
[ -f "${stack_yml}" ] || { echo "  FAIL: stack.yml not found"; exit 1; }
grep -q 'paused-html' "${stack_yml}" || { echo "  FAIL: stack.yml missing paused-html service"; exit 1; }
grep -q 'traefik.http.routers.__STACK_NAME__-paused' "${stack_yml}" || { echo "  FAIL: stack.yml missing configurable paused router"; exit 1; }
grep -q '__PUBLIC_WEB_HOST__' "${stack_yml}" || { echo "  FAIL: stack.yml missing configurable web host"; exit 1; }
echo "  PASS: stack has paused-html service with Traefik labels"

# ── Test 5: Application services start at 0 replicas ────────────────
echo "  Test 5: Application services start at 0 replicas"
for svc in sample-web sample-api worker-sidecar dashboard-web sample-service; do
    # Check that the service has replicas: 0 in the stack file
    grep -A20 "^  ${svc}:" "${stack_yml}" | grep -q 'replicas: 0' || {
        echo "  FAIL: ${svc} does not have replicas: 0"
        exit 1
    }
done
echo "  PASS: All application services start at 0 replicas"

exit 0
