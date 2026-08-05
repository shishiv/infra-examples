#!/bin/sh
# mock-docker.sh - Mock docker CLI for unit tests
# shellcheck disable=SC2034
#
# Creates a temporary mock docker script and prepends it to PATH.
# Call mock_docker_setup at the start of each test and
# mock_docker_teardown at the end.
#
# Usage:
#   . ./fixtures/mock-docker.sh
#   mock_docker_setup
#   # ... test code ...
#   mock_docker_teardown

MOCK_DOCKER_DIR=""
MOCK_DOCKER_CALLS_FILE=""

mock_docker_setup() {
    MOCK_DOCKER_DIR="$(mktemp -d)"
    MOCK_DOCKER_CALLS_FILE="${MOCK_DOCKER_DIR}/calls"

    : > "${MOCK_DOCKER_CALLS_FILE}"

    # Write the state dir path so the mock script can find it
    echo "${MOCK_DOCKER_DIR}" > "${MOCK_DOCKER_DIR}/state_dir"

    cat > "${MOCK_DOCKER_DIR}/docker" << 'MOCKSCRIPT'
#!/bin/sh
# Mock docker - records calls and returns controlled responses
MOCK_STATE_DIR="$(cat "$(dirname "$0")/state_dir")"
CALLS_FILE="${MOCK_STATE_DIR}/calls"
STACKS_FILE="${MOCK_STATE_DIR}/stacks"
SERVICES_FILE="${MOCK_STATE_DIR}/services"
LOGIN_FAIL="${MOCK_STATE_DIR}/login_fail"
PULL_FAIL="${MOCK_STATE_DIR}/pull_fail"
PULL_FAIL_IMAGE="${MOCK_STATE_DIR}/pull_fail_image"
DEPLOY_FAIL="${MOCK_STATE_DIR}/deploy_fail"
SCALE_FAIL="${MOCK_STATE_DIR}/scale_fail"
MANIFEST_FAIL="${MOCK_STATE_DIR}/manifest_fail"
INFO_FAIL="${MOCK_STATE_DIR}/info_fail"
STACK_LS_FAIL="${MOCK_STATE_DIR}/stack_ls_fail"
SERVICE_LS_FAIL="${MOCK_STATE_DIR}/service_ls_fail"
SERVICE_STATE_FILE="${MOCK_STATE_DIR}/service_state"
SIGNAL_PID_FILE="${MOCK_STATE_DIR}/signal_pid"
LOCK_CALLS_FILE="${MOCK_STATE_DIR}/lock_calls"

echo "docker $*" >> "${CALLS_FILE}"

# Record whether the staging lock is held for every mutation the scripts make,
# so tests can assert that no Docker call happens outside the lock.
if [ -n "${STAGING_LOCK_DIR:-}" ]; then
    if [ -d "${STAGING_LOCK_DIR}" ]; then
        echo "held docker $*" >> "${LOCK_CALLS_FILE}"
    else
        echo "free docker $*" >> "${LOCK_CALLS_FILE}"
    fi
fi

cmd="$1"
shift

case "${cmd}" in
    info)
        if [ -f "${INFO_FAIL}" ]; then
            echo "Cannot connect to the Docker daemon (mock)" >&2
            exit 1
        fi
        echo "active"
        ;;
    network)
        subcmd="$1"; shift
        [ "${subcmd}" = inspect ] || exit 1
        case "$*" in
            *"{{.Id}}"*) echo "traefik-network-id" ;;
            *"{{.Driver}} {{.Scope}}"*) echo "overlay swarm" ;;
            *) echo "traefik-network-id" ;;
        esac
        ;;
    login)
        if [ -f "${LOGIN_FAIL}" ]; then
            echo "Error: login failed (mock)" >&2
            exit 1
        fi
        echo "Login Succeeded"
        ;;
    logout)
        echo "Logout Succeeded"
        ;;
    pull)
        if [ -f "${PULL_FAIL}" ]; then
            echo "Error: pull failed (mock)" >&2
            exit 1
        fi
        if [ -f "${PULL_FAIL_IMAGE}" ]; then
            case "$*" in
                *"$(cat "${PULL_FAIL_IMAGE}")"*)
                    echo "Error: pull failed (mock)" >&2
                    exit 1
                    ;;
            esac
        fi
        echo "Pulling from $*"
        ;;
    manifest)
        [ "$1" = inspect ] || exit 1
        [ ! -f "${MANIFEST_FAIL}" ] || exit 1
        echo '{}'
        ;;
    stack)
        subcmd="$1"
        shift
        case "${subcmd}" in
            ls)
                if [ -f "${STACK_LS_FAIL}" ]; then
                    echo "Cannot connect to the Docker daemon (mock)" >&2
                    exit 1
                fi
                format_flag=""
                while [ $# -gt 0 ]; do
                    case "$1" in
                        --format)
                            format_flag="$2"; shift 2 ;;
                        *)
                            shift ;;
                    esac
                done
                if [ -f "${STACKS_FILE}" ]; then
                    while IFS= read -r line; do
                        [ -z "${line}" ] && continue
                        case "${format_flag}" in
                            '{{.Name}}')
                                echo "${line}"
                                ;;
                            *)
                                echo "${line}"
                                ;;
                        esac
                    done < "${STACKS_FILE}"
                fi
                ;;
            deploy)
                if [ -f "${DEPLOY_FAIL}" ]; then
                    echo "Error: deploy failed (mock)" >&2
                    exit 1
                fi
                # Deterministic interrupt: signal the recorded shell exactly once
                # while it is waiting on this deploy.
                if [ -f "${SIGNAL_PID_FILE}" ]; then
                    signal_pid=$(cat "${SIGNAL_PID_FILE}")
                    rm -f "${SIGNAL_PID_FILE}"
                    kill -TERM "${signal_pid}" 2>/dev/null || true
                fi
                echo "Deploying stack..."
                echo "staging" > "${STACKS_FILE}"
                cat > "${SERVICES_FILE}" << 'SVC'
staging_paused-html
staging_sample-web
staging_sample-api
staging_worker-sidecar
staging_dashboard-web
staging_sample-service
SVC
                ;;
            services)
                format_flag=""
                while [ $# -gt 0 ]; do
                    case "$1" in
                        --format)
                            format_flag="$2"; shift 2 ;;
                        *)
                            shift ;;
                    esac
                done
                if [ -f "${SERVICES_FILE}" ]; then
                    while IFS= read -r line; do
                        [ -z "${line}" ] && continue
                        name="${line}"
                        case "${format_flag}" in
                            '{{.Replicas}}')
                                echo "1/1"
                                ;;
                            '{{.Name}}')
                                echo "${name}"
                                ;;
                            'table {{.Name}}\t{{.Mode}}\t{{.Replicas}}\t{{.Image}}')
                                printf '%-30s %-10s %-10s %s\n' "${name}" "replicated" "1/1" "registry.example.invalid/portfolio/mock:latest"
                                ;;
                            *)
                                echo "${name}"
                                ;;
                        esac
                    done < "${SERVICES_FILE}"
                fi
                ;;
            rm)
                echo "Removing stack..."
                rm -f "${STACKS_FILE}"
                rm -f "${SERVICES_FILE}"
                ;;
            *)
                echo "Unknown stack subcommand: ${subcmd}" >&2
                exit 1
                ;;
        esac
        ;;
    service)
        subcmd="$1"
        shift
        case "${subcmd}" in
            ls)
                if [ -f "${SERVICE_LS_FAIL}" ]; then
                    echo "Cannot connect to the Docker daemon (mock)" >&2
                    exit 1
                fi
                format_flag=""
                filter_flag=""
                while [ $# -gt 0 ]; do
                    case "$1" in
                        --format)
                            format_flag="$2"; shift 2 ;;
                        --filter)
                            filter_flag="$2"; shift 2 ;;
                        *)
                            shift ;;
                    esac
                done
                if [ "${filter_flag}" = "name=edge-router" ] && [ "${format_flag}" = "{{.Replicas}}" ]; then
                    echo "1/1"
                    exit 0
                fi
                if [ -f "${SERVICES_FILE}" ]; then
                    while IFS= read -r line; do
                        [ -z "${line}" ] && continue
                        name="${line}"
                        # Apply filter if present
                        if [ -n "${filter_flag}" ]; then
                            filter_name="${filter_flag#name=}"
                            case "${name}" in
                                *"${filter_name}"*) ;;
                                *) continue ;;
                            esac
                        fi
                        case "${format_flag}" in
                            '{{.Replicas}}')
                                echo "1/1"
                                ;;
                            '{{.Name}}')
                                echo "${name}"
                                ;;
                            'table {{.Name}}\t{{.Mode}}\t{{.Replicas}}\t{{.Image}}')
                                printf '%-30s %-10s %-10s %s\n' "${name}" "replicated" "1/1" "registry.example.invalid/portfolio/mock:latest"
                                ;;
                            *)
                                echo "${name}"
                                ;;
                        esac
                    done < "${SERVICES_FILE}"
                fi
                ;;
            scale)
                if [ -f "${SCALE_FAIL}" ]; then
                    echo "Error: scale failed (mock)" >&2
                    exit 1
                fi
                echo "Scaling..."
                ;;
            inspect)
                service=""
                format=""
                while [ $# -gt 0 ]; do
                    case "$1" in
                        --format) format="$2"; shift 2 ;;
                        *) service="$1"; shift ;;
                    esac
                done
                if [ "${service}" = "edge-router" ]; then
                    echo "traefik-network-id "
                    exit 0
                fi
                state=$(grep "^${service}|" "${SERVICE_STATE_FILE}" 2>/dev/null || true)
                [ -n "${state}" ] || exit 1
                image=$(printf '%s' "${state}" | cut -d'|' -f2)
                replicas=$(printf '%s' "${state}" | cut -d'|' -f3)
                case "${format}" in
                    '{{.Spec.TaskTemplate.ContainerSpec.Image}}') echo "${image}" ;;
                    '{{.Spec.Mode.Replicated.Replicas}}') echo "${replicas}" ;;
                    *) echo "${state}" ;;
                esac
                ;;
            *)
                echo "Unknown service subcommand: ${subcmd}" >&2
                exit 1
                ;;
        esac
        ;;
    *)
        echo "Unknown docker command: ${cmd}" >&2
        exit 1
        ;;
esac
MOCKSCRIPT

    cat > "${MOCK_DOCKER_DIR}/getent" << 'MOCKGETENT'
#!/bin/sh
echo "${MOCK_DNS_IP:-192.0.2.10} STREAM $3"
MOCKGETENT
    cat > "${MOCK_DOCKER_DIR}/curl" << 'MOCKCURL'
#!/bin/sh
echo "curl $*" >> "$(dirname "$0")/calls"
printf '%s' "${MOCK_HTTP_STATUS:-200}"
MOCKCURL
    cat > "${MOCK_DOCKER_DIR}/sleep" << 'MOCKSLEEP'
#!/bin/sh
exit 0
MOCKSLEEP

    chmod +x "${MOCK_DOCKER_DIR}/docker" "${MOCK_DOCKER_DIR}/getent" "${MOCK_DOCKER_DIR}/curl" "${MOCK_DOCKER_DIR}/sleep"
    PATH="${MOCK_DOCKER_DIR}:${PATH}"
    EXPECTED_EDGE_IP="${EXPECTED_EDGE_IP:-192.0.2.10}"
    export PATH EXPECTED_EDGE_IP
}

mock_docker_teardown() {
    rm -rf "${MOCK_DOCKER_DIR}"
}

# ── Mock state helpers ──────────────────────────────────────────────
mock_docker_set_stacks() {
    printf '%s\n' "$@" > "${MOCK_DOCKER_DIR}/stacks"
}

mock_docker_set_services() {
    printf '%s\n' "$@" > "${MOCK_DOCKER_DIR}/services"
}

mock_docker_set_login_fail() {
    touch "${MOCK_DOCKER_DIR}/login_fail"
}

mock_docker_set_pull_fail() {
    touch "${MOCK_DOCKER_DIR}/pull_fail"
}

# Fail only the pulls whose image reference contains "$1", so a test can make one
# manifest undeployable while another one still starts.
mock_docker_set_pull_fail_image() {
    printf '%s' "$1" > "${MOCK_DOCKER_DIR}/pull_fail_image"
}

mock_docker_set_deploy_fail() {
    touch "${MOCK_DOCKER_DIR}/deploy_fail"
}

mock_docker_set_scale_fail() {
    touch "${MOCK_DOCKER_DIR}/scale_fail"
}

mock_docker_set_manifest_fail() { touch "${MOCK_DOCKER_DIR}/manifest_fail"; }

mock_docker_set_info_fail() { touch "${MOCK_DOCKER_DIR}/info_fail"; }

mock_docker_set_stack_ls_fail() { touch "${MOCK_DOCKER_DIR}/stack_ls_fail"; }

mock_docker_set_service_ls_fail() { touch "${MOCK_DOCKER_DIR}/service_ls_fail"; }

mock_docker_set_service_state() {
    printf '%s\n' "$@" > "${MOCK_DOCKER_DIR}/service_state"
}

mock_docker_get_calls() {
    if [ -f "${MOCK_DOCKER_CALLS_FILE}" ]; then
        cat "${MOCK_DOCKER_CALLS_FILE}"
    fi
}

# Path a shell can write its own PID to before exec-ing the script under test;
# the mock signals it once, from inside the next stack deploy.
mock_docker_signal_pid_file() {
    printf '%s\n' "${MOCK_DOCKER_DIR}/signal_pid"
}

mock_docker_get_lock_calls() {
    if [ -f "${MOCK_DOCKER_DIR}/lock_calls" ]; then
        cat "${MOCK_DOCKER_DIR}/lock_calls"
    fi
}
