#!/bin/sh
# deploy.sh - transactionally deploy one validated staging manifest

# shellcheck source=staging/scripts/lib.sh
. "$(dirname "$0")/lib.sh"

[ "$#" -eq 1 ] || die "Usage: deploy.sh <manifest.yml>"
manifest="$1"
validate_manifest "${manifest}"

lock_acquire
trap 'lock_release' EXIT

candidate=$(mktemp)
trap 'rm -f "${candidate}"; lock_release' EXIT
cp "${manifest}" "${candidate}"
sha=$(manifest_read_field "${candidate}" sha)
capture_prior_lifecycle

staging_interrupted && die "Deploy was interrupted before the staging stack was touched"

log "Deploying validated manifest ${sha}"
deployed=1
STAGING_LOCK_HELD=1 "${SCRIPT_DIR}/start.sh" "${candidate}" || deployed=0
if staging_interrupted; then
    warn "The candidate deploy was interrupted"
    deployed=0
fi

if [ "${deployed}" -eq 1 ]; then
    archive_active_manifest
    cp "${candidate}" "${ACTIVE_MANIFEST}"
    log "Deploy complete; up to ${MANIFEST_HISTORY_LIMIT} prior manifests retained"
    exit 0
fi

warn "Candidate deploy did not complete; restoring the lifecycle staging had before it"
reconcile_prior_lifecycle \
    || die "Deploy failed and the previous staging lifecycle could not be confirmed; staging stays active for the expiry timer to retry"
die "Deploy failed; the previous staging lifecycle and TTL were restored"
