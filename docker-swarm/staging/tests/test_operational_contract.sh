#!/bin/sh
# test_operational_contract.sh - static staging-only deployment contracts
# shellcheck disable=SC1091,SC2034

. ../scripts/lib.sh

stack="${STAGING_DIR}/stack.yml"
manifest="${STAGING_DIR}/tests/fixtures/valid-manifest.yml"

echo "  Test 1: all six services have HTTP health checks and resource limits"
[ "$(grep -c 'test: \["CMD", "wget"' "${stack}")" -eq 6 ] || { echo "  FAIL: expected six HTTP health checks"; exit 1; }
[ "$(grep -c '^        limits:' "${stack}")" -eq 6 ] || { echo "  FAIL: expected six resource limits"; exit 1; }

echo "  Test 2: configured edge uses an external overlay contract"
grep -q '^  __EDGE_NETWORK__:' "${stack}" || exit 1
grep -A3 '^  __EDGE_NETWORK__:' "${stack}" | grep -q 'external: true' || exit 1
[ "$(grep -c 'traefik.docker.network=__EDGE_NETWORK__' "${stack}")" -eq 5 ] || exit 1

echo "  Test 3: paused image is immutable manifest input"
grep -A2 '^  paused-html:' "${stack}" | grep -q 'image: ""' || exit 1
grep -q 'paused-html:' "${manifest}" || exit 1
grep -q ':latest' "${stack}" && { echo "  FAIL: mutable runtime image found"; exit 1; }

PORTFOLIO_ROOT="$(cd ../../.. && pwd -P)"
WORKFLOW_DIR="${PORTFOLIO_ROOT}/github-actions/workflows"

echo "  Test 4: staging deploy workflow is retired"
[ ! -e "${WORKFLOW_DIR}/deploy-staging.yml" ] || {
    echo "  FAIL: retired staging deploy workflow is still present"
    exit 1
}

echo "  Test 5: the publish workflow builds only the module-owned paused image"
publish="${WORKFLOW_DIR}/publish-paused-html.yml"
[ -f "${publish}" ] || { echo "  FAIL: paused-page publish workflow not found"; exit 1; }
grep -q "ghcr.io/\${{ github.repository_owner }}/paused-page-example" "${publish}" || exit 1
grep -q 'docker-swarm/staging/paused-html' "${publish}" || exit 1
grep -q ':sha-' "${publish}" || { echo "  FAIL: published tag is not an immutable SHA tag"; exit 1; }
grep -q 'validate_immutable_image' "${publish}" || { echo "  FAIL: published reference is not validated"; exit 1; }
[ "$(grep -c 'docker build' "${publish}")" -eq 1 ] || { echo "  FAIL: publish workflow builds more than paused-html"; exit 1; }
grep -qE 'stack deploy|start\.sh|remote-deploy' "${publish}" && { echo "  FAIL: publish workflow deploys staging"; exit 1; }

echo "  Test 6: staging stack contains no persistent data volumes"
if grep -q '^volumes:' "${stack}"; then
    echo "  FAIL: persistent volume found"
    exit 1
fi
exit 0
