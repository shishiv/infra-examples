#!/bin/sh
# preflight.sh - read-only central Traefik, Swarm, and DNS checks

# shellcheck source=staging/scripts/lib.sh
. "$(dirname "$0")/lib.sh"

require_docker
require_command getent
[ -n "${EXPECTED_EDGE_IP}" ] || die "EXPECTED_EDGE_IP is required for DNS preflight"

swarm_state=$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null || true)
[ "${swarm_state}" = active ] || die "Docker Swarm is not active on this node"

network_id=$(docker network inspect "${EDGE_NETWORK}" --format '{{.Id}}' 2>/dev/null || true)
[ -n "${network_id}" ] || die "Central edge network not found: ${EDGE_NETWORK}"
network_contract=$(docker network inspect "${EDGE_NETWORK}" --format '{{.Driver}} {{.Scope}}' 2>/dev/null || true)
[ "${network_contract}" = "overlay swarm" ] || die "Edge network must be a swarm overlay: ${network_contract:-missing}"

traefik_networks=$(docker service inspect "${EDGE_SERVICE}" --format '{{range .Spec.TaskTemplate.Networks}}{{.Target}} {{end}}' 2>/dev/null || true)
case " ${traefik_networks} " in *" ${network_id} "*) ;; *) die "Edge service is not attached to ${EDGE_NETWORK}" ;; esac
traefik_replicas=$(docker service ls --filter "name=${EDGE_SERVICE}" --format '{{.Replicas}}' 2>/dev/null || true)
traefik_ready=${traefik_replicas%/*}
traefik_desired=${traefik_replicas#*/}
if ! { [ -n "${traefik_replicas}" ] && [ "${traefik_ready}" -gt 0 ] 2>/dev/null && [ "${traefik_ready}" -eq "${traefik_desired}" ] 2>/dev/null; }; then
    die "Central Traefik service is not ready: ${traefik_replicas:-missing}"
fi

for domain in ${PUBLIC_HOSTS}; do
    resolved=$(getent ahostsv4 "${domain}" 2>/dev/null | awk '{print $1}' | sort -u || true)
    printf '%s\n' "${resolved}" | grep -qx "${EXPECTED_EDGE_IP}" || die "DNS preflight failed for ${domain}: expected ${EXPECTED_EDGE_IP}, got ${resolved:-nothing}"
done

log "Preflight passed; no DNS or Traefik state was modified"
