#!/bin/sh
# smoke-test.sh - reproducible replica and HTTPS health checks for staging

# shellcheck source=staging/scripts/lib.sh
. "$(dirname "$0")/lib.sh"

stack_name="${1:-${STACK_NAME}}"
require_docker
require_command curl
[ -n "${EXPECTED_EDGE_IP}" ] || die "EXPECTED_EDGE_IP is required for HTTP smoke tests"

docker stack ls --format '{{.Name}}' 2>/dev/null | grep -qx "${stack_name}" || die "Stack '${stack_name}' does not exist"

wait_service_ready() {
    service_name="$1"
    attempt=1
    replicas="missing"
    while [ "${attempt}" -le 10 ]; do
        if docker service ls --format '{{.Name}}' 2>/dev/null | grep -qx "${service_name}"; then
            replicas=$(docker service ls --filter "name=${service_name}" --format '{{.Replicas}}' 2>/dev/null || echo 0/0)
            ready=${replicas%/*}
            desired=${replicas#*/}
            if [ "${desired}" -gt 0 ] 2>/dev/null && [ "${ready}" -eq "${desired}" ] 2>/dev/null; then
                return 0
            fi
        fi
        attempt=$(( attempt + 1 ))
        sleep 2
    done
    die "Service '${service_name}' is not ready (${replicas})"
}

for service in ${STAGING_SERVICES}; do
    service_name="${stack_name}_${service}"
    wait_service_ready "${service_name}"
done

check_https_health() {
    domain="$1"
    attempt=1
    while [ "${attempt}" -le 10 ]; do
        status=$(curl --silent --show-error --output /dev/null --write-out '%{http_code}' \
            --connect-timeout 3 --max-time 8 --resolve "${domain}:443:${EXPECTED_EDGE_IP}" \
            "https://${domain}/health" 2>/dev/null || true)
        [ "${status}" = 200 ] && return 0
        attempt=$(( attempt + 1 ))
        sleep 2
    done
    die "HTTPS health check failed for ${domain}/health (last status: ${status:-none})"
}

for domain in ${PUBLIC_HOSTS}; do
    check_https_health "${domain}"
done

log "Smoke tests passed with deterministic HTTPS /health checks"
