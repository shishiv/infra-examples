#!/bin/sh
# stop.sh - Stop the staging environment
#
# Scales all application services to 0 replicas, leaving the
# paused-html service running so the domain returns an explicit
# paused response.  Clears the TTL and state.
#
# Usage: stop.sh

# shellcheck source=staging/scripts/lib.sh
. "$(dirname "$0")/lib.sh"

owns_lock=0
if [ "${STAGING_LOCK_HELD:-0}" -ne 1 ]; then
    lock_acquire
    owns_lock=1
fi

tmp_stack=""
stop_failed=0
cleanup_stop() {
    [ -z "${tmp_stack}" ] || rm -f "${tmp_stack}" "${tmp_stack}.tmp"
    [ "${owns_lock}" -eq 0 ] || lock_release
}
trap cleanup_stop EXIT
trap 'exit 130' INT TERM

log "Stopping staging environment..."

require_docker

# ── Verify we are operating on the staging stack ───────────────────
stack_names=$(swarm_stack_names) || die "Unable to query Docker Swarm stacks; staging state left unchanged for retry"
if ! swarm_has_name "${stack_names}" "${STACK_NAME}"; then
    warn "Stack '${STACK_NAME}' does not exist - nothing to stop"
    clear_ttl
    write_state "paused"
    log "Staging already stopped."
    exit 0
fi

service_names=$(swarm_service_names) || die "Unable to query Docker Swarm services; staging state left unchanged for retry"

# ── Scale all application services to 0 ────────────────────────────
# paused-html stays at 1 replica so the domain returns a paused response.
for svc in sample-web sample-api worker-sidecar dashboard-web sample-service; do
    service_name="${STACK_NAME}_${svc}"
    if swarm_has_name "${service_names}" "${service_name}"; then
        log "Scaling ${service_name} to 0..."
        run_redacted docker service scale "${service_name}=0" || {
            warn "Failed to scale ${service_name}"
            stop_failed=1
        }
    fi
done

# ── Ensure paused-html is running ──────────────────────────────────
paused_service="${STACK_NAME}_paused-html"
if ! swarm_has_name "${service_names}" "${paused_service}"; then
    if [ -f "${ACTIVE_MANIFEST}" ]; then
        validate_manifest "${ACTIVE_MANIFEST}"
        tmp_stack=$(mktemp)
        render_stack_from_manifest "${ACTIVE_MANIFEST}" "${tmp_stack}"
        log "Deploying immutable paused-html service from the active manifest..."
        run_redacted docker stack deploy --prune -c "${tmp_stack}" "${STACK_NAME}" || {
            warn "Failed to ensure paused-html service"
            stop_failed=1
        }
    else
        warn "Cannot bootstrap paused-html without an active immutable manifest"
    fi
fi

# ── Clear state ────────────────────────────────────────────────────
# The TTL and state are only cleared once the stack really is stopped, so an
# expired TTL keeps being retried by the expiry timer instead of being lost.
if [ "${stop_failed}" -ne 0 ]; then
    die "Staging stop did not complete; TTL and state left unchanged for retry"
fi

clear_ttl
write_state "paused"

log "Staging environment stopped. Domain returns paused response."
