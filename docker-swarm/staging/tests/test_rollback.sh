#!/bin/sh
# test_rollback.sh - test three-slot history and registry rollback checks
# shellcheck disable=SC1091,SC2034

. ./fixtures/mock-docker.sh

SCRIPTS_DIR="$(cd ../scripts && pwd -P)"
RUNTIME_DIR=$(mktemp -d)
STAGING_RUNTIME_DIR="${RUNTIME_DIR}"
STAGING_LOCK_DIR="${RUNTIME_DIR}/lock"
export STAGING_RUNTIME_DIR STAGING_LOCK_DIR

mock_docker_setup
trap 'mock_docker_teardown; rm -rf "${RUNTIME_DIR}"' EXIT
mkdir -p "${RUNTIME_DIR}/.manifest-history"

# shellcheck source=staging/scripts/lib.sh
. ../scripts/lib.sh

make_manifest() {
    sha="$1"
    destination="$2"
    sed "s/^sha:.*/sha: \"${sha}\"/" fixtures/valid-manifest.yml > "${destination}"
}

active_sha=1111111111111111111111111111111111111111
history_1_sha=2222222222222222222222222222222222222222
history_2_sha=3333333333333333333333333333333333333333
history_3_sha=4444444444444444444444444444444444444444
echo "  Test 1: successful deployments retain exactly three prior manifests"
make_manifest "${active_sha}" "${RUNTIME_DIR}/.active-manifest.yml"
archive_active_manifest
make_manifest "${history_1_sha}" "${RUNTIME_DIR}/.active-manifest.yml"
archive_active_manifest
make_manifest "${history_2_sha}" "${RUNTIME_DIR}/.active-manifest.yml"
archive_active_manifest
make_manifest "${history_3_sha}" "${RUNTIME_DIR}/.active-manifest.yml"
grep -q "${history_2_sha}" "${RUNTIME_DIR}/.manifest-history/1.yml" || exit 1
grep -q "${history_1_sha}" "${RUNTIME_DIR}/.manifest-history/2.yml" || exit 1
grep -q "${active_sha}" "${RUNTIME_DIR}/.manifest-history/3.yml" || exit 1
[ "$(find "${RUNTIME_DIR}/.manifest-history" -name '*.yml' | wc -l)" -eq 3 ] || exit 1

make_manifest "${active_sha}" "${RUNTIME_DIR}/.active-manifest.yml"
make_manifest "${history_1_sha}" "${RUNTIME_DIR}/.manifest-history/1.yml"
make_manifest "${history_2_sha}" "${RUNTIME_DIR}/.manifest-history/2.yml"
make_manifest "${history_3_sha}" "${RUNTIME_DIR}/.manifest-history/3.yml"

echo "  Test 2: rollback one slot verifies images and consumes history"
REGISTRY_TOKEN=fixture "${SCRIPTS_DIR}/rollback.sh" 1 >/dev/null
grep -q "${history_1_sha}" "${RUNTIME_DIR}/.active-manifest.yml" || { echo "  FAIL: slot 1 was not restored"; exit 1; }
grep -q "${history_2_sha}" "${RUNTIME_DIR}/.manifest-history/1.yml" || { echo "  FAIL: history did not shift"; exit 1; }
manifest_checks=$(mock_docker_get_calls | grep -c '^docker manifest inspect ' || true)
[ "${manifest_checks}" -eq 6 ] || { echo "  FAIL: expected six registry image checks, got ${manifest_checks}"; exit 1; }

echo "  Test 3: rollback can select the third retained manifest"
make_manifest "${history_1_sha}" "${RUNTIME_DIR}/.manifest-history/1.yml"
make_manifest "${history_2_sha}" "${RUNTIME_DIR}/.manifest-history/2.yml"
make_manifest "${history_3_sha}" "${RUNTIME_DIR}/.manifest-history/3.yml"
REGISTRY_TOKEN=fixture "${SCRIPTS_DIR}/rollback.sh" 3 >/dev/null
grep -q "${history_3_sha}" "${RUNTIME_DIR}/.active-manifest.yml" || { echo "  FAIL: slot 3 was not restored"; exit 1; }
[ ! -e "${RUNTIME_DIR}/.manifest-history/1.yml" ] || { echo "  FAIL: consumed history remains"; exit 1; }

echo "  Test 4: unavailable registry image blocks rollback before deploy"
make_manifest "${history_1_sha}" "${RUNTIME_DIR}/.manifest-history/1.yml"
before_sha=$(sed -n 's/^sha: "\([^"]*\)"/\1/p' "${RUNTIME_DIR}/.active-manifest.yml")
mock_docker_set_manifest_fail
if REGISTRY_TOKEN=fixture "${SCRIPTS_DIR}/rollback.sh" 1 >/dev/null 2>&1; then
    echo "  FAIL: rollback accepted an unavailable image"
    exit 1
fi
after_sha=$(sed -n 's/^sha: "\([^"]*\)"/\1/p' "${RUNTIME_DIR}/.active-manifest.yml")
[ "${before_sha}" = "${after_sha}" ] || { echo "  FAIL: failed rollback changed active manifest"; exit 1; }

echo "  Test 5: a failed rollback of a paused environment ends in a confirmed stop"
mock_docker_teardown
mock_docker_setup
make_manifest "${active_sha}" "${RUNTIME_DIR}/.active-manifest.yml"
make_manifest "${history_1_sha}" "${RUNTIME_DIR}/.manifest-history/1.yml"
printf 'paused\n' > "${STAGING_STATE_FILE}"
rm -f "${TTL_FILE}"
if MOCK_HTTP_STATUS=503 REGISTRY_TOKEN=fixture "${SCRIPTS_DIR}/rollback.sh" 1 >/dev/null 2>&1; then
    echo "  FAIL: rollback reported success despite a failing smoke test"
    exit 1
fi
calls=$(mock_docker_get_calls)
printf '%s\n' "${calls}" | grep -q '^docker stack deploy' \
    || { echo "  FAIL: the rollback never deployed, so the failure window was not exercised"; exit 1; }
printf '%s\n' "${calls}" | grep -q "docker service scale ${STACK_NAME}_sample-api=0" \
    || { echo "  FAIL: paused was recorded without stopping the rolled-back services"; exit 1; }
grep -qx paused "${STAGING_STATE_FILE}" || { echo "  FAIL: a failed rollback did not restore the paused lifecycle"; exit 1; }
[ -f "${TTL_FILE}" ] && { echo "  FAIL: a failed rollback left a TTL on a stopped environment"; exit 1; }
grep -q "${active_sha}" "${RUNTIME_DIR}/.active-manifest.yml" || { echo "  FAIL: a failed rollback published the rolled-back manifest"; exit 1; }
grep -q "${history_1_sha}" "${RUNTIME_DIR}/.manifest-history/1.yml" || { echo "  FAIL: a failed rollback consumed its history slot"; exit 1; }
[ -d "${STAGING_LOCK_DIR}" ] && { echo "  FAIL: a failed rollback never released its lock"; exit 1; }

echo "  Test 6: a failed rollback of an active environment restores it with its remaining TTL"
mock_docker_teardown
mock_docker_setup
unpullable=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
sed -e "s/^sha:.*/sha: \"${history_1_sha}\"/" \
    -e "s#sample-web@sha256:[0-9a-f]*#sample-web@sha256:${unpullable}#" \
    fixtures/valid-manifest.yml > "${RUNTIME_DIR}/.manifest-history/1.yml"
make_manifest "${active_sha}" "${RUNTIME_DIR}/.active-manifest.yml"
expiry=$(( $(date +%s) + 7200 ))
printf 'active\n' > "${STAGING_STATE_FILE}"
printf '%d\n' "${expiry}" > "${TTL_FILE}"
mock_docker_set_pull_fail_image "sample-web@sha256:${unpullable}"
if REGISTRY_TOKEN=fixture "${SCRIPTS_DIR}/rollback.sh" 1 >/dev/null 2>&1; then
    echo "  FAIL: rollback reported success with an unpullable image"
    exit 1
fi
calls=$(mock_docker_get_calls)
printf '%s\n' "${calls}" | grep -q "docker pull registry.example.invalid/portfolio/sample-web@sha256:${unpullable}" \
    || { echo "  FAIL: the rollback never tried the target manifest"; exit 1; }
[ "$(printf '%s\n' "${calls}" | grep -c '^docker stack deploy')" -eq 1 ] \
    || { echo "  FAIL: the last active manifest was not redeployed exactly once"; exit 1; }
grep -qx active "${STAGING_STATE_FILE}" || { echo "  FAIL: a failed rollback paused a running environment"; exit 1; }
[ "$(cat "${TTL_FILE}")" = "${expiry}" ] || { echo "  FAIL: a failed rollback replaced the remaining TTL"; exit 1; }
grep -q "${active_sha}" "${RUNTIME_DIR}/.active-manifest.yml" || { echo "  FAIL: a failed rollback changed the active manifest"; exit 1; }
grep -q "${history_1_sha}" "${RUNTIME_DIR}/.manifest-history/1.yml" || { echo "  FAIL: a failed rollback consumed its history slot"; exit 1; }
mock_docker_get_lock_calls | grep -qE '^free docker (stack (rm|deploy)|service scale)' \
    && { echo "  FAIL: a failed rollback mutated staging with no lock held"; exit 1; }

exit 0
