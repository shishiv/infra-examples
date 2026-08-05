#!/bin/sh
# test_drift_reset.sh - observational drift and deterministic synthetic reset
# shellcheck disable=SC1091,SC2034

. ./fixtures/mock-docker.sh

SCRIPTS_DIR="$(cd ../scripts && pwd -P)"
RUNTIME_DIR=$(mktemp -d)
STAGING_RUNTIME_DIR="${RUNTIME_DIR}"
STAGING_LOCK_DIR="${RUNTIME_DIR}/lock"
export STAGING_RUNTIME_DIR STAGING_LOCK_DIR
mock_docker_setup
trap 'mock_docker_teardown; rm -rf "${RUNTIME_DIR}"' EXIT
cp fixtures/valid-manifest.yml "${RUNTIME_DIR}/.active-manifest.yml"
printf 'active\n' > "${RUNTIME_DIR}/.staging-state"

# Load manifest helpers after setting the isolated runtime directory.
. ../scripts/lib.sh
service_state=""
for service in ${STAGING_SERVICES}; do
    image=$(manifest_read_field "${ACTIVE_MANIFEST}" "images.${service}")
    service_state="${service_state}${STACK_NAME}_${service}|${image}|1\n"
done
# shellcheck disable=SC2059
printf "${service_state}" > "${MOCK_DOCKER_DIR}/service_state"

echo "  Test 1: matching live image and replica observations report no drift"
"${SCRIPTS_DIR}/drift-report.sh" >/dev/null

echo "  Test 2: drift exits two and never reconciles automatically"
sed -i 's/staging_sample-api|\([^|]*\)|1/staging_sample-api|\1|2/' "${MOCK_DOCKER_DIR}/service_state"
drift_output="${RUNTIME_DIR}/drift-report.out"
set +e
"${SCRIPTS_DIR}/drift-report.sh" >"${drift_output}" 2>&1
status=$?
set -e
[ "${status}" -eq 2 ] || { echo "  FAIL: drift report exit was ${status}"; exit 1; }
grep -q '^DRIFT sample-api ' "${drift_output}" || exit 1
mock_docker_get_calls | grep -q 'docker service update' && { echo "  FAIL: drift was reconciled"; exit 1; }
mock_docker_get_calls | grep -q 'docker stack deploy' && { echo "  FAIL: drift redeployed the stack"; exit 1; }

echo "  Test 3: synthetic reset removes and recreates only staging"
mock_docker_set_stacks staging
mock_docker_set_services staging_paused-html staging_sample-web staging_sample-api staging_worker-sidecar staging_dashboard-web staging_sample-service
expiry=$(( $(date +%s) + 7200 ))
printf '%d\n' "${expiry}" > "${TTL_FILE}"
REGISTRY_TOKEN=fixture "${SCRIPTS_DIR}/reset-synthetic.sh" >/dev/null
calls=$(mock_docker_get_calls)
printf '%s\n' "${calls}" | grep -q '^docker stack rm staging$' || exit 1
printf '%s\n' "${calls}" | grep -q '^docker stack deploy .* staging$' || exit 1
grep -qx active "${RUNTIME_DIR}/.staging-state" || exit 1
[ "$(cat "${TTL_FILE}")" = "${expiry}" ] || { echo "  FAIL: reset extended the TTL"; exit 1; }
