#!/bin/sh
# rollback.sh - restore one of the three retained immutable manifests

# shellcheck source=staging/scripts/lib.sh
. "$(dirname "$0")/lib.sh"

steps="${1:-1}"
case "${steps}" in 1|2|3) ;; *) die "Usage: rollback.sh [1|2|3]" ;; esac
target="${MANIFEST_HISTORY_DIR}/${steps}.yml"

lock_acquire
trap 'registry_logout; lock_release' EXIT
capture_prior_lifecycle

if [ ! -f "${target}" ]; then
    warn "Rollback history slot ${steps} is empty; stopping staging instead"
    STAGING_LOCK_HELD=1 "${SCRIPT_DIR}/stop.sh"
    exit 0
fi

validate_manifest "${target}"
require_docker
registry_login
log "Verifying every rollback image still exists in the container registry"
verify_manifest_images_exist "${target}"

sha=$(manifest_read_field "${target}" sha)
staging_interrupted && die "Rollback was interrupted before the staging stack was touched"

restored=1
STAGING_LOCK_HELD=1 "${SCRIPT_DIR}/start.sh" "${target}" || restored=0
if staging_interrupted; then
    warn "The rollback deploy was interrupted"
    restored=0
fi

if [ "${restored}" -eq 0 ]; then
    warn "Rollback deploy did not complete; restoring the lifecycle staging had before it"
    reconcile_prior_lifecycle \
        || die "Rollback failed and the previous staging lifecycle could not be confirmed; staging stays active for the expiry timer to retry"
    die "Rollback failed; the previous staging lifecycle and TTL were restored"
fi

cp "${target}" "${ACTIVE_MANIFEST}"
consume_manifest_history "${steps}"
log "Rollback complete; restored manifest ${sha}"
