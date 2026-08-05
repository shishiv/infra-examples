#!/bin/sh
# reset-synthetic.sh - recreate only the ephemeral staging stack from its active manifest
#
# Usage: reset-synthetic.sh [--activate]
#   Default: the pre-reset lifecycle (active, paused, or expired) and the
#   remaining TTL are restored after the stack is recreated.
#   --activate: explicitly leave staging active with a fresh TTL.

# shellcheck source=staging/scripts/lib.sh
. "$(dirname "$0")/lib.sh"

activate=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        --activate) activate=1 ;;
        *) die "Usage: reset-synthetic.sh [--activate]" ;;
    esac
    shift
done

[ -f "${ACTIVE_MANIFEST}" ] || die "Synthetic reset requires an active manifest"
validate_manifest "${ACTIVE_MANIFEST}"
require_docker

snapshot=""
owns_lock=0
cleaned_up=0
cleanup_synthetic_reset() {
    [ "${cleaned_up}" -eq 0 ] || return 0
    cleaned_up=1
    registry_logout
    [ -z "${snapshot}" ] || rm -f "${snapshot}"
    [ "${owns_lock}" -eq 0 ] || lock_release
}
trap cleanup_synthetic_reset EXIT
trap 'exit 130' INT TERM

"${SCRIPT_DIR}/preflight.sh"
registry_login
verify_manifest_images_exist "${ACTIVE_MANIFEST}"
registry_logout

owns_lock=1
lock_acquire
# Once the reset owns the lock an interrupt may no longer exit: the fail-safe
# lifecycle restore below still has to run, and it has to run under this lock.
# The lock's handler only records the interrupt, so the single EXIT trap
# reinstalled here releases the lock once the restore is done.
trap cleanup_synthetic_reset EXIT
snapshot=$(mktemp)
cp "${ACTIVE_MANIFEST}" "${snapshot}"

capture_prior_lifecycle

# The reset clears ephemeral container state only. Unless activation is asked
# for explicitly, it never extends the environment's life: the pre-reset TTL and
# lifecycle are restored, so a paused or expired environment ends up stopped.
# `paused` is only ever recorded by a stop that confirmed it, and staging stays
# recorded `active` whenever that confirmation is missing, so the expiry timer
# keeps retrying instead of losing the environment.
lifecycle_restored=0
lifecycle_restore_status=0
restore_prior_lifecycle() {
    [ "${lifecycle_restored}" -eq 0 ] || return "${lifecycle_restore_status}"
    lifecycle_restored=1
    restore_prior_ttl
    if [ "${PRIOR_STATE}" = active ] && [ "${PRIOR_REMAINING}" -gt 0 ]; then
        write_state active
        log "Restored the pre-reset active lifecycle with its remaining TTL"
        return 0
    fi
    if [ "${PRIOR_STATE}" = active ]; then
        log "Pre-reset TTL had already expired; returning staging to paused"
    else
        log "Staging was paused before the reset; returning it to paused"
    fi
    STAGING_LOCK_HELD=1 "${SCRIPT_DIR}/stop.sh" && return 0
    restore_prior_ttl
    write_state active
    lifecycle_restore_status=1
    return 1
}

staging_interrupted && die "Synthetic reset was interrupted before the staging stack was touched"

log "Removing the staging stack to clear all synthetic ephemeral container state"
run_redacted docker stack rm "${STACK_NAME}" || true
attempt=1
while :; do
    stack_names=$(swarm_stack_names) || die "Unable to query Docker Swarm while waiting for staging stack removal"
    swarm_has_name "${stack_names}" "${STACK_NAME}" || break
    [ "${attempt}" -le 30 ] || die "Timed out waiting for staging stack removal"
    sleep 1
    attempt=$(( attempt + 1 ))
done

reset_failed=0
if staging_interrupted; then
    warn "Synthetic reset was interrupted after the staging stack was removed"
    reset_failed=1
elif ! STAGING_LOCK_HELD=1 "${SCRIPT_DIR}/start.sh" "${snapshot}"; then
    warn "Synthetic reset could not recreate the staging stack"
    reset_failed=1
fi

if [ "${reset_failed}" -eq 0 ] && staging_interrupted; then
    warn "Synthetic reset was interrupted while recreating the staging stack"
    reset_failed=1
fi

if [ "${reset_failed}" -ne 0 ]; then
    restore_prior_lifecycle \
        || die "Synthetic reset failed and staging could not be confirmed stopped; it stays active for the expiry timer to retry"
    die "Synthetic reset failed; the pre-reset lifecycle and TTL were restored"
fi

if [ "${activate}" -eq 1 ]; then
    log "Synthetic reset activated staging explicitly with a fresh TTL"
else
    restore_prior_lifecycle \
        || die "Synthetic reset recreated the stack but could not confirm the paused lifecycle; staging stays active for the expiry timer to retry"
fi

log "Synthetic reset complete; no persistent or real data was used"
