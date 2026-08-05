#!/bin/sh
# start.sh - preflight and deploy the complete immutable staging manifest

# shellcheck source=staging/scripts/lib.sh
. "$(dirname "$0")/lib.sh"

owns_lock=0
if [ "${STAGING_LOCK_HELD:-0}" -ne 1 ]; then
    lock_acquire
    owns_lock=1
    capture_prior_lifecycle
fi

tmp_stack=""
stack_touched=0
cleanup_start() {
    [ -z "${tmp_stack}" ] || rm -f "${tmp_stack}" "${tmp_stack}.tmp"
    registry_logout
    [ "${owns_lock}" -eq 0 ] || lock_release
}
trap cleanup_start EXIT
# A caller that holds the lock owns the reconciliation, so this run fails fast
# and lets the parent restore the lifecycle. When this run owns the lock it
# keeps the recording interrupt handler instead, so a failure or an interrupt
# after the stack was touched is reconciled here, under that same lock.
if [ "${owns_lock}" -eq 0 ]; then
    trap 'exit 130' INT TERM
fi

start_failed() {
    if [ "${owns_lock}" -eq 0 ] || [ "${stack_touched}" -eq 0 ]; then
        die "$1"
    fi
    warn "$1"
    reconcile_prior_lifecycle \
        || die "Staging start failed and the previous lifecycle could not be confirmed; staging stays active for the expiry timer to retry"
    die "Staging start failed; the previous lifecycle and TTL were restored"
}

manifest="${1:-${ACTIVE_MANIFEST}}"
validate_manifest "${manifest}"
ttl=$(manifest_read_field "${manifest}" ttl)

log "Running central Traefik and DNS preflight"
"${SCRIPT_DIR}/preflight.sh"

require_docker
log "Authenticating to the container registry"
registry_login

for service in ${STAGING_SERVICES}; do
    image=$(manifest_read_field "${manifest}" "images.${service}")
    log "Pulling ${image}"
    run_redacted docker pull "${image}" || die "Failed to pull ${image}"
done

staging_interrupted && start_failed "Staging start was interrupted before the stack was touched"

tmp_stack=$(mktemp)
render_stack_from_manifest "${manifest}" "${tmp_stack}"

log "Deploying stack '${STACK_NAME}'"
stack_touched=1
run_redacted docker stack deploy --with-registry-auth --prune -c "${tmp_stack}" "${STACK_NAME}" || start_failed "Stack deploy failed"

for service in ${STAGING_APP_SERVICES}; do
    log "Scaling ${service} to one replica"
    run_redacted docker service scale "${STACK_NAME}_${service}=1" || start_failed "Failed to scale ${service}"
done

staging_interrupted && start_failed "Staging start was interrupted while deploying the stack"

"${SCRIPT_DIR}/smoke-test.sh" "${STACK_NAME}" || start_failed "Smoke tests failed"

staging_interrupted && start_failed "Staging start was interrupted after the stack was deployed"

write_ttl "${ttl}"
write_state active
if [ "${owns_lock}" -eq 1 ]; then
    if [ ! -f "${ACTIVE_MANIFEST}" ] || ! cmp -s "${manifest}" "${ACTIVE_MANIFEST}"; then
        archive_active_manifest
        cp "${manifest}" "${ACTIVE_MANIFEST}"
    fi
fi
log "Staging started with synthetic data contract and ${ttl}h TTL"
