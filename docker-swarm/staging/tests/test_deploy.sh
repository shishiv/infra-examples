#!/bin/sh
# test_deploy.sh - Test deploy command with valid and invalid manifests
# shellcheck disable=SC1091,SC2034

. ./fixtures/mock-docker.sh
. ../scripts/lib.sh

SCRIPT_DIR="$(cd ../scripts && pwd -P)"
STAGING_DIR="$(cd ./fixtures && pwd -P)"
RUNTIME_DIR=$(mktemp -d)
STAGING_RUNTIME_DIR="${RUNTIME_DIR}"
STAGING_LOCK_DIR="${RUNTIME_DIR}/lock"
export STAGING_RUNTIME_DIR STAGING_LOCK_DIR
MANIFEST_DIR="${STAGING_DIR}"
TTL_FILE="${RUNTIME_DIR}/.staging-ttl"
STAGING_STATE_FILE="${RUNTIME_DIR}/.staging-state"
ACTIVE_MANIFEST="${RUNTIME_DIR}/.active-manifest.yml"

rm -f "${TTL_FILE}" "${STAGING_STATE_FILE}" "${ACTIVE_MANIFEST}"

mock_docker_setup
trap 'mock_docker_teardown; rm -rf "${RUNTIME_DIR}"' EXIT

# ── Test 1: Deploy with valid manifest ──────────────────────────────
echo "  Test 1: Deploy with valid manifest"
REGISTRY_TOKEN=fixture "${SCRIPT_DIR}/deploy.sh" "${STAGING_DIR}/valid-manifest.yml" 2>&1 || {
    echo "  FAIL: deploy.sh exited with error"
    exit 1
}

[ -f "${ACTIVE_MANIFEST}" ] || { echo "  FAIL: active manifest not saved"; exit 1; }
echo "  PASS: deploy with valid manifest succeeded"

# ── Test 2: Deploy with missing manifest file ───────────────────────
echo "  Test 2: Deploy with missing manifest file"
if "${SCRIPT_DIR}/deploy.sh" "/nonexistent/manifest.yml" 2>&1; then
    echo "  FAIL: deploy should fail with missing manifest"
    exit 1
fi
echo "  PASS: deploy correctly rejected missing manifest"

# ── Test 3: Deploy with invalid image reference ─────────────────────
echo "  Test 3: Deploy with invalid image reference"
# Create a manifest with a mutable tag
invalid_manifest="${RUNTIME_DIR}/invalid-manifest.yml"
sed 's#registry.example.invalid/portfolio/sample-web@sha256:[0-9a-f]*#registry.example.invalid/portfolio/sample-web:latest#' "${STAGING_DIR}/valid-manifest.yml" > "${invalid_manifest}"

if REGISTRY_TOKEN=fixture "${SCRIPT_DIR}/deploy.sh" "${invalid_manifest}" 2>&1; then
    echo "  FAIL: deploy should reject mutable tag 'latest'"
    rm -f "${invalid_manifest}"
    exit 1
fi
rm -f "${invalid_manifest}"
echo "  PASS: deploy correctly rejected mutable tag"

# ── Test 4: Deploy with missing sha ─────────────────────────────────
echo "  Test 4: Deploy with missing sha"
no_sha_manifest="${RUNTIME_DIR}/no-sha-manifest.yml"
sed 's/^sha:.*/sha: ""/' "${STAGING_DIR}/valid-manifest.yml" > "${no_sha_manifest}"

if REGISTRY_TOKEN=fixture "${SCRIPT_DIR}/deploy.sh" "${no_sha_manifest}" 2>&1; then
    echo "  FAIL: deploy should reject manifest with empty sha"
    rm -f "${no_sha_manifest}"
    exit 1
fi
rm -f "${no_sha_manifest}"
echo "  PASS: deploy correctly rejected manifest with empty sha"

# ── Test 5: an interrupted deploy returns a paused environment to paused ──
echo "  Test 5: Interrupted deploy of a paused environment ends in a confirmed stop"
candidate_sha=cccccccccccccccccccccccccccccccccccccccc
candidate_manifest="${RUNTIME_DIR}/candidate-manifest.yml"
sed "s/^sha:.*/sha: \"${candidate_sha}\"/" "${STAGING_DIR}/valid-manifest.yml" > "${candidate_manifest}"
printf 'paused\n' > "${STAGING_STATE_FILE}"
rm -f "${TTL_FILE}"

if REGISTRY_TOKEN=fixture sh -c 'printf "%s\n" $$ > "$1"; shift; exec "$@"' \
        _ "$(mock_docker_signal_pid_file)" "${SCRIPT_DIR}/deploy.sh" "${candidate_manifest}" >/dev/null 2>&1; then
    echo "  FAIL: an interrupted deploy reported success"
    exit 1
fi
grep -qx paused "${STAGING_STATE_FILE}" || { echo "  FAIL: an interrupted deploy left a paused environment recorded active"; exit 1; }
[ -f "${TTL_FILE}" ] && { echo "  FAIL: an interrupted deploy left a TTL on a stopped environment"; exit 1; }
mock_docker_get_calls | grep -q "docker service scale staging_sample-api=0" \
    || { echo "  FAIL: paused was recorded without stopping the deployed services"; exit 1; }
grep -q "${candidate_sha}" "${ACTIVE_MANIFEST}" && { echo "  FAIL: an interrupted deploy published the candidate manifest"; exit 1; }
[ -d "${STAGING_LOCK_DIR}" ] && { echo "  FAIL: an interrupted deploy never released its lock"; exit 1; }
echo "  PASS: an interrupted deploy stops the stack it brought up"

# ── Test 6: an interrupted deploy keeps the remaining TTL ───────────
echo "  Test 6: Interrupted deploy of an active environment restores its remaining TTL"
expiry=$(( $(date +%s) + 7200 ))
printf 'active\n' > "${STAGING_STATE_FILE}"
printf '%d\n' "${expiry}" > "${TTL_FILE}"
before_sha=$(sed -n 's/^sha: "\([^"]*\)"/\1/p' "${ACTIVE_MANIFEST}")

if REGISTRY_TOKEN=fixture sh -c 'printf "%s\n" $$ > "$1"; shift; exec "$@"' \
        _ "$(mock_docker_signal_pid_file)" "${SCRIPT_DIR}/deploy.sh" "${candidate_manifest}" >/dev/null 2>&1; then
    echo "  FAIL: an interrupted deploy reported success"
    exit 1
fi
grep -qx active "${STAGING_STATE_FILE}" || { echo "  FAIL: an interrupted deploy paused a running environment"; exit 1; }
[ "$(cat "${TTL_FILE}")" = "${expiry}" ] || { echo "  FAIL: an interrupted deploy replaced the remaining TTL"; exit 1; }
after_sha=$(sed -n 's/^sha: "\([^"]*\)"/\1/p' "${ACTIVE_MANIFEST}")
[ "${before_sha}" = "${after_sha}" ] || { echo "  FAIL: an interrupted deploy changed the active manifest"; exit 1; }
mock_docker_get_lock_calls | grep -qE '^free docker (stack (rm|deploy)|service scale)' \
    && { echo "  FAIL: staging was mutated with no lock held"; exit 1; }
echo "  PASS: an interrupted deploy restores the previous manifest and its TTL"

# ── Test 7: a failed restore never keeps the candidate's fresh TTL ───
echo "  Test 7: A failed restore of the previous manifest keeps its remaining TTL"
previous_sha=dddddddddddddddddddddddddddddddddddddddd
unpullable=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
sed -e "s/^sha:.*/sha: \"${previous_sha}\"/" \
    -e "s#sample-web@sha256:[0-9a-f]*#sample-web@sha256:${unpullable}#" \
    "${STAGING_DIR}/valid-manifest.yml" > "${ACTIVE_MANIFEST}"
mock_docker_set_pull_fail_image "sample-web@sha256:${unpullable}"
expiry=$(( $(date +%s) + 7200 ))
printf 'active\n' > "${STAGING_STATE_FILE}"
printf '%d\n' "${expiry}" > "${TTL_FILE}"

if REGISTRY_TOKEN=fixture sh -c 'printf "%s\n" $$ > "$1"; shift; exec "$@"' \
        _ "$(mock_docker_signal_pid_file)" "${SCRIPT_DIR}/deploy.sh" "${candidate_manifest}" >/dev/null 2>&1; then
    echo "  FAIL: a deploy whose restore failed reported success"
    exit 1
fi
mock_docker_get_calls | grep -q "docker pull registry.example.invalid/portfolio/sample-web@sha256:${unpullable}" \
    || { echo "  FAIL: the previous manifest was never redeployed, so the restore never failed"; exit 1; }
grep -qx active "${STAGING_STATE_FILE}" || { echo "  FAIL: a failed restore paused a running environment"; exit 1; }
[ "$(cat "${TTL_FILE}")" = "${expiry}" ] || { echo "  FAIL: a failed restore kept the candidate's fresh TTL"; exit 1; }
grep -q "${candidate_sha}" "${ACTIVE_MANIFEST}" && { echo "  FAIL: a failed deploy published the candidate manifest"; exit 1; }
echo "  PASS: a failed restore leaves the environment on its original TTL"

exit 0
