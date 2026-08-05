#!/bin/sh
# drift-report.sh - observe image and replica drift without reconciling it

# shellcheck source=staging/scripts/lib.sh
. "$(dirname "$0")/lib.sh"

require_docker
[ -f "${ACTIVE_MANIFEST}" ] || die "No active manifest is available for drift comparison"
validate_manifest "${ACTIVE_MANIFEST}"

if is_staging_active; then app_replicas=1; else app_replicas=0; fi
drift=0
echo "=== Staging Drift Report (observational only) ==="
for service in ${STAGING_SERVICES}; do
    service_name="${STACK_NAME}_${service}"
    expected_image=$(manifest_read_field "${ACTIVE_MANIFEST}" "images.${service}")
    expected_replicas="${app_replicas}"
    [ "${service}" = paused-html ] && expected_replicas=1

    actual_image=$(docker service inspect "${service_name}" --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}' 2>/dev/null || true)
    actual_replicas=$(docker service inspect "${service_name}" --format '{{.Spec.Mode.Replicated.Replicas}}' 2>/dev/null || true)
    image_matches=0
    [ "${actual_image}" = "${expected_image}" ] && image_matches=1
    case "${actual_image}" in "${expected_image}"@sha256:*) image_matches=1 ;; esac

    if [ "${image_matches}" -eq 1 ] && [ "${actual_replicas}" = "${expected_replicas}" ]; then
        printf 'OK    %s\n' "${service}"
    else
        printf 'DRIFT %s expected_image=%s actual_image=%s expected_replicas=%s actual_replicas=%s\n' \
            "${service}" "${expected_image}" "${actual_image:-missing}" "${expected_replicas}" "${actual_replicas:-missing}"
        drift=1
    fi
done

echo "No changes were applied."
[ "${drift}" -eq 0 ] || exit 2
