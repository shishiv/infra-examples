#!/bin/sh
# extend-ttl.sh - Extend the staging TTL
#
# Usage: extend-ttl.sh [hours]
#   Default: 4 hours from now

# shellcheck source=staging/scripts/lib.sh
. "$(dirname "$0")/lib.sh"

hours="${1:-4}"

# Validate hours is a positive integer
case "${hours}" in
    ''|*[!0-9]*)
        die "Hours must be a positive integer, got: ${hours}"
        ;;
esac
[ "${hours}" -gt 0 ] 2>/dev/null || die "Hours must be greater than 0"

# Check staging is active
is_staging_active || die "Staging is not active - cannot extend TTL"

write_ttl "${hours}"
expiry=$(cat "${TTL_FILE}")
log "TTL extended to ${hours}h (now expires at $(date -d "@${expiry}" 2>/dev/null || echo "${expiry}"))"
