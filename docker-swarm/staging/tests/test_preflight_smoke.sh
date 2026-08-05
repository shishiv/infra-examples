#!/bin/sh
# test_preflight_smoke.sh - deterministic read-only preflight and HTTP smoke checks
# shellcheck disable=SC1091,SC2034

. ./fixtures/mock-docker.sh

SCRIPT_DIR="$(cd ../scripts && pwd -P)"
RUNTIME_DIR=$(mktemp -d)
STAGING_RUNTIME_DIR="${RUNTIME_DIR}"
STAGING_LOCK_DIR="${RUNTIME_DIR}/lock"
export STAGING_RUNTIME_DIR STAGING_LOCK_DIR
mock_docker_setup
trap 'mock_docker_teardown; rm -rf "${RUNTIME_DIR}"' EXIT

echo "  Test 1: preflight observes expected central Traefik and DNS state"
"${SCRIPT_DIR}/preflight.sh" >/dev/null
calls=$(mock_docker_get_calls)
printf '%s\n' "${calls}" | grep -q '^docker network inspect ' || exit 1
printf '%s\n' "${calls}" | grep -q '^docker service inspect edge-router' || exit 1
printf '%s\n' "${calls}" | grep -q 'docker stack deploy' && { echo "  FAIL: preflight changed stack state"; exit 1; }

echo "  Test 2: DNS mismatch blocks preflight without writes"
MOCK_DNS_IP=192.0.2.99; export MOCK_DNS_IP
if "${SCRIPT_DIR}/preflight.sh" >/dev/null 2>&1; then echo "  FAIL: mismatched DNS was accepted"; exit 1; fi
unset MOCK_DNS_IP

echo "  Test 3: smoke test checks all fixed HTTPS health endpoints"
mock_docker_set_stacks staging
mock_docker_set_services staging_paused-html staging_sample-web staging_sample-api staging_worker-sidecar staging_dashboard-web staging_sample-service
"${SCRIPT_DIR}/smoke-test.sh" >/dev/null
health_calls=$(mock_docker_get_calls | grep -c 'https://.*/health' || true)
[ "${health_calls}" -eq 4 ] || { echo "  FAIL: expected four routed HTTP checks, got ${health_calls}"; exit 1; }

echo "  Test 4: non-200 HTTP status fails reproducibly after ten attempts"
MOCK_HTTP_STATUS=503; export MOCK_HTTP_STATUS
if "${SCRIPT_DIR}/smoke-test.sh" >/dev/null 2>&1; then echo "  FAIL: unhealthy HTTP response was accepted"; exit 1; fi
