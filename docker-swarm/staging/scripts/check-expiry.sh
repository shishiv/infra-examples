#!/bin/sh
# check-expiry.sh - Check staging TTL and stop if expired
#
# Designed to be run from a systemd timer every 5 minutes.
# Only stops staging if the TTL has expired.
#
# Usage: check-expiry.sh

# shellcheck source=staging/scripts/lib.sh
. "$(dirname "$0")/lib.sh"

# If staging is not active, nothing to do
is_staging_active || {
    log "Staging is not active - skipping expiry check"
    exit 0
}

ttl_remaining=$(staging_ttl_remaining)
if [ "${ttl_remaining}" -gt 0 ]; then
    hours=$(( ttl_remaining / 3600 ))
    minutes=$(( (ttl_remaining % 3600) / 60 ))
    log "Staging TTL still valid: ${hours}h ${minutes}m remaining"
    exit 0
fi

log "Staging TTL expired - stopping staging environment"
"${SCRIPT_DIR}/stop.sh" || die "Stop during expiry check failed; staging stays active and the next timer run retries"
log "Staging stopped due to TTL expiry"
