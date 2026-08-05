#!/bin/sh
# status.sh - Report staging environment status
#
# Usage: status.sh

# shellcheck source=staging/scripts/lib.sh
. "$(dirname "$0")/lib.sh"

require_docker

state="unknown"
if is_staging_active; then
    state="active"
elif [ -f "${STAGING_STATE_FILE}" ] && grep -q 'paused' "${STAGING_STATE_FILE}" 2>/dev/null; then
    state="paused"
fi

ttl_remaining=$(staging_ttl_remaining)

# ── Check Docker stack ─────────────────────────────────────────────
if stack_names=$(swarm_stack_names); then
    swarm_has_name "${stack_names}" "${STACK_NAME}" && stack_exists=yes || stack_exists=no
else
    stack_exists="unknown (Swarm query failed)"
fi

echo "=== Staging Environment Status ==="
echo "Stack name:     ${STACK_NAME}"
echo "State:          ${state}"
echo "Stack exists:   ${stack_exists}"

if [ "${stack_exists}" = yes ]; then
    echo ""
    echo "--- Services ---"
    run_redacted docker stack services "${STACK_NAME}" --format 'table {{.Name}}\t{{.Mode}}\t{{.Replicas}}\t{{.Image}}' || echo "  (unable to list services)"
fi

if [ "${ttl_remaining}" -gt 0 ]; then
    hours=$(( ttl_remaining / 3600 ))
    minutes=$(( (ttl_remaining % 3600) / 60 ))
    echo ""
    echo "TTL remaining:  ${hours}h ${minutes}m"
else
    echo ""
    echo "TTL remaining:  expired or not set"
fi

echo ""
echo "--- Active Manifest ---"
if [ -f "${ACTIVE_MANIFEST}" ]; then
    redact < "${ACTIVE_MANIFEST}"
else
    echo "  (none)"
fi
