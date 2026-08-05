#!/bin/sh
# lib.sh - shared lifecycle and manifest helpers for this portfolio module
# shellcheck disable=SC2034

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
STAGING_DIR="$(cd "${SCRIPT_DIR}/.." && pwd -P)"
MODULE_DIR="$(cd "${STAGING_DIR}/.." && pwd -P)"
CONFIG_FILE="${PORTFOLIO_CONFIG_FILE:-${MODULE_DIR}/.env}"
STAGING_RUNTIME_DIR="${STAGING_RUNTIME_DIR:-${STAGING_DIR}}"
LOCK_DIR="${STAGING_LOCK_DIR:-/tmp/portfolio-infra-staging-lock}"
TTL_FILE="${STAGING_RUNTIME_DIR}/.staging-ttl"
ACTIVE_MANIFEST="${STAGING_RUNTIME_DIR}/.active-manifest.yml"
STAGING_STATE_FILE="${STAGING_RUNTIME_DIR}/.staging-state"
MANIFEST_HISTORY_DIR="${STAGING_RUNTIME_DIR}/.manifest-history"
MANIFEST_HISTORY_LIMIT=3
STAGING_SERVICES="paused-html sample-web sample-api worker-sidecar dashboard-web sample-service"
STAGING_APP_SERVICES="sample-web sample-api worker-sidecar dashboard-web sample-service"

# The optional module-local file contains operator configuration only. It is
# parsed, never sourced, and only allow-listed values are read. Secrets are
# supplied transiently as REGISTRY_TOKEN and are never read from this file.
read_operator_env() {
    env_file="${CONFIG_FILE}"
    [ -f "${env_file}" ] || return 0
    sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*\(.*\)\$/\1/p" "${env_file}" \
        | sed -e 's/[[:space:]]*$//' -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'\$/\1/" \
        | tail -n 1
}

STACK_NAME="${STACK_NAME:-$(read_operator_env STACK_NAME)}"
STACK_NAME="${STACK_NAME:-staging}"
EXPECTED_EDGE_IP="${EXPECTED_EDGE_IP:-$(read_operator_env EXPECTED_EDGE_IP)}"
EDGE_NETWORK="${EDGE_NETWORK:-$(read_operator_env EDGE_NETWORK)}"
EDGE_NETWORK="${EDGE_NETWORK:-edge-public}"
EDGE_SERVICE="${EDGE_SERVICE:-$(read_operator_env EDGE_SERVICE)}"
EDGE_SERVICE="${EDGE_SERVICE:-edge-router}"
EDGE_CERT_RESOLVER="${EDGE_CERT_RESOLVER:-$(read_operator_env EDGE_CERT_RESOLVER)}"
EDGE_CERT_RESOLVER="${EDGE_CERT_RESOLVER:-default}"
PUBLIC_WEB_HOST="${PUBLIC_WEB_HOST:-$(read_operator_env PUBLIC_WEB_HOST)}"
PUBLIC_WEB_HOST="${PUBLIC_WEB_HOST:-app.example.test}"
PUBLIC_API_HOST="${PUBLIC_API_HOST:-$(read_operator_env PUBLIC_API_HOST)}"
PUBLIC_API_HOST="${PUBLIC_API_HOST:-api.example.test}"
PUBLIC_DASHBOARD_HOST="${PUBLIC_DASHBOARD_HOST:-$(read_operator_env PUBLIC_DASHBOARD_HOST)}"
PUBLIC_DASHBOARD_HOST="${PUBLIC_DASHBOARD_HOST:-dashboard.example.test}"
PUBLIC_SERVICE_HOST="${PUBLIC_SERVICE_HOST:-$(read_operator_env PUBLIC_SERVICE_HOST)}"
PUBLIC_SERVICE_HOST="${PUBLIC_SERVICE_HOST:-service.example.test}"
REGISTRY_HOST="${REGISTRY_HOST:-$(read_operator_env REGISTRY_HOST)}"
REGISTRY_HOST="${REGISTRY_HOST:-registry.example.invalid}"
REGISTRY_NAMESPACE="${REGISTRY_NAMESPACE:-$(read_operator_env REGISTRY_NAMESPACE)}"
REGISTRY_NAMESPACE="${REGISTRY_NAMESPACE:-portfolio}"
REGISTRY_USERNAME="${REGISTRY_USERNAME:-$(read_operator_env REGISTRY_USERNAME)}"
REGISTRY_USERNAME="${REGISTRY_USERNAME:-portfolio-user}"
PUBLIC_HOSTS="${PUBLIC_WEB_HOST} ${PUBLIC_API_HOST} ${PUBLIC_DASHBOARD_HOST} ${PUBLIC_SERVICE_HOST}"
PAUSED_IMAGE_REPOSITORY="${REGISTRY_HOST}/${REGISTRY_NAMESPACE}/paused-html"

log()  { printf '[INFO]  %s\n' "$*"; }
warn() { printf '[WARN]  %s\n' "$*" >&2; }
die()  { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

redact() {
    sed 's/--password-stdin[^" ]*/--password-stdin ***REDACTED***/g; s/REGISTRY_TOKEN=[^ ]*/REGISTRY_TOKEN=***REDACTED***/g; s/ghp_[a-zA-Z0-9]*/***REDACTED***/g; s/gho_[a-zA-Z0-9]*/***REDACTED***/g; s/ghs_[a-zA-Z0-9]*/***REDACTED***/g; s/ghr_[a-zA-Z0-9]*/***REDACTED***/g'
}

# Run a command with its combined output redacted while preserving its exit
# status. A plain `cmd | redact` pipeline always reports sed's status, which
# would silently defeat every `|| die` and `|| warn` guard.
# The output is never buffered to disk, so an interrupted command cannot leave
# an un-redacted file behind.
run_redacted() {
    { redacted_status=$( { { redacted_rc=0; "$@" 2>&1 || redacted_rc=$?; printf '%s\n' "${redacted_rc}" >&3; } | redact >&4; } 3>&1 ); } 4>&1
    return "${redacted_status}"
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "$1 is required but not found in PATH"
}

require_docker() {
    require_command docker
    docker info >/dev/null 2>&1 || die "Docker daemon is not reachable; environment state left unchanged"
}

# Swarm queries keep their exit status so callers can tell "the object is
# absent" apart from "the query failed" and never record a state they did not
# actually observe.
swarm_stack_names() { docker stack ls --format '{{.Name}}' 2>/dev/null; }
swarm_service_names() { docker service ls --format '{{.Name}}' 2>/dev/null; }
swarm_has_name() { printf '%s\n' "$1" | grep -qx "$2"; }

# A POSIX shell resumes the script after running an INT or TERM trap, so a
# handler may never clean up inline. Holding the lock therefore only records the
# interrupt: the owning script decides at its next checkpoint whether it can
# stop immediately or has to reconcile the lifecycle first, and the single EXIT
# trap releases the lock once staging is no longer being touched.
STAGING_INTERRUPTED=0
staging_note_interrupt() {
    STAGING_INTERRUPTED=1
    warn "Interrupt received; staging will be reconciled before this operation exits"
}
staging_interrupted() { [ "${STAGING_INTERRUPTED}" -eq 1 ]; }

# The lock records its owner, so a release can only ever remove the lock this
# shell acquired and never one a concurrent staging operation holds.
lock_acquire() {
    if ! mkdir "${LOCK_DIR}" 2>/dev/null; then
        die "Another staging operation is in progress (lock held at ${LOCK_DIR})"
    fi
    printf '%d\n' "$$" > "${LOCK_DIR}/owner" || die "Unable to record the staging lock owner at ${LOCK_DIR}"
    trap 'lock_release' EXIT
    trap staging_note_interrupt INT TERM
}

lock_release() {
    lock_owner=$(cat "${LOCK_DIR}/owner" 2>/dev/null || true)
    [ "${lock_owner}" = "$$" ] || return 0
    rm -rf "${LOCK_DIR}" 2>/dev/null || true
}

manifest_read_field() {
    manifest="$1"
    field="$2"
    [ -f "${manifest}" ] || die "Manifest not found: ${manifest}"

    case "${field}" in
        images.*)
            service="${field#images.}"
            awk -v srv="${service}" '
                /^images:[[:space:]]*$/ { in_images=1; next }
                in_images && /^[^[:space:]]/ { in_images=0 }
                in_images {
                    key=$1; sub(/:$/, "", key)
                    if (key == srv) {
                        value=$0; sub(/^[[:space:]]*[^:]+:[[:space:]]*/, "", value)
                        gsub(/^"|"[[:space:]]*$/, "", value)
                        print value; found=1; exit
                    }
                }
                END { if (!found) exit 1 }
            ' "${manifest}"
            ;;
        *)
            awk -v f="${field}" '
                $1 == f":" {
                    value=$0; sub(/^[^:]+:[[:space:]]*/, "", value)
                    gsub(/^"|"[[:space:]]*$/, "", value)
                    print value; found=1; exit
                }
                END { if (!found) exit 1 }
            ' "${manifest}"
            ;;
    esac
}

validate_immutable_image() {
    image="$1"
    case "${image}" in
        "${REGISTRY_HOST}/${REGISTRY_NAMESPACE}/"*@sha256:*)
            digest="${image##*@sha256:}"
            [ "${#digest}" -eq 64 ] || return 1
            case "${digest}" in *[!0-9a-fA-F]*) return 1 ;; esac
            ;;
        "${REGISTRY_HOST}/${REGISTRY_NAMESPACE}/"*:sha-*)
            commit="${image##*:sha-}"
            [ "${#commit}" -eq 40 ] || return 1
            case "${commit}" in *[!0-9a-fA-F]*) return 1 ;; esac
            ;;
        *) return 1 ;;
    esac
}

validate_manifest() {
    manifest="$1"
    [ -f "${manifest}" ] || die "Manifest not found: ${manifest}"

    version=$(manifest_read_field "${manifest}" version 2>/dev/null || true)
    [ "${version}" = "1" ] || die "Unsupported manifest version: ${version:-missing}"

    sha=$(manifest_read_field "${manifest}" sha 2>/dev/null || true)
    [ "${#sha}" -eq 40 ] || die "Manifest sha must be a full 40-character commit SHA"
    case "${sha}" in *[!0-9a-fA-F]*) die "Manifest sha must be hexadecimal" ;; esac

    data_mode=$(manifest_read_field "${manifest}" data_mode 2>/dev/null || true)
    [ "${data_mode}" = "synthetic" ] || die "Manifest data_mode must be 'synthetic'"

    ttl=$(manifest_read_field "${manifest}" ttl 2>/dev/null || true)
    case "${ttl}" in ''|*[!0-9]*) die "Manifest ttl must be a positive integer" ;; esac
    [ "${ttl}" -gt 0 ] || die "Manifest ttl must be greater than zero"

    for service in ${STAGING_SERVICES}; do
        image=$(manifest_read_field "${manifest}" "images.${service}" 2>/dev/null || true)
        [ -n "${image}" ] || die "Manifest is missing required image: ${service}"
        validate_immutable_image "${image}" || die "Image must be an immutable registry digest or sha-<40 hex> tag: ${image}"
        if [ "${service}" = "paused-html" ]; then
            case "${image}" in
                "${PAUSED_IMAGE_REPOSITORY}"@sha256:*|"${PAUSED_IMAGE_REPOSITORY}":sha-*) ;;
                *) die "paused-html must use the configured paused image repository" ;;
            esac
        fi
    done
}

registry_login() {
    if [ -n "${REGISTRY_TOKEN:-}" ]; then
        printf '%s' "${REGISTRY_TOKEN}" | run_redacted docker login "${REGISTRY_HOST}" -u "${REGISTRY_USERNAME}" --password-stdin || die "Container registry login failed"
        REGISTRY_LOGGED_IN=1
    else
        warn "REGISTRY_TOKEN not set; only public registry images can be inspected or pulled"
        REGISTRY_LOGGED_IN=0
    fi
}

registry_logout() {
    if [ "${REGISTRY_LOGGED_IN:-0}" -eq 1 ]; then
        run_redacted docker logout "${REGISTRY_HOST}" || true
        REGISTRY_LOGGED_IN=0
    fi
}

verify_manifest_images_exist() {
    manifest="$1"
    for service in ${STAGING_SERVICES}; do
        image=$(manifest_read_field "${manifest}" "images.${service}")
        docker manifest inspect "${image}" >/dev/null 2>&1 || die "Rollback image is unavailable in the container registry: ${image}"
    done
}

render_stack_from_manifest() {
    manifest="$1"
    output="$2"
    cp "${STAGING_DIR}/stack.yml" "${output}"
    sed -i \
        -e "s#__STACK_NAME__#${STACK_NAME}#g" \
        -e "s#__EDGE_NETWORK__#${EDGE_NETWORK}#g" \
        -e "s#__EDGE_CERT_RESOLVER__#${EDGE_CERT_RESOLVER}#g" \
        -e "s#__PUBLIC_WEB_HOST__#${PUBLIC_WEB_HOST}#g" \
        -e "s#__PUBLIC_API_HOST__#${PUBLIC_API_HOST}#g" \
        -e "s#__PUBLIC_DASHBOARD_HOST__#${PUBLIC_DASHBOARD_HOST}#g" \
        -e "s#__PUBLIC_SERVICE_HOST__#${PUBLIC_SERVICE_HOST}#g" \
        "${output}"
    for service in ${STAGING_SERVICES}; do
        image=$(manifest_read_field "${manifest}" "images.${service}")
        awk -v svc="${service}" -v img="${image}" '
            /^  [a-zA-Z0-9-]+:$/ { current=$1; sub(/:$/, "", current); in_service=(current == svc) }
            in_service && /image: ""/ { $0="    image: \"" img "\""; in_service=0 }
            { print }
        ' "${output}" > "${output}.tmp" && mv "${output}.tmp" "${output}"
    done
}

archive_active_manifest() {
    [ -f "${ACTIVE_MANIFEST}" ] || return 0
    mkdir -p "${MANIFEST_HISTORY_DIR}"
    if [ -f "${MANIFEST_HISTORY_DIR}/2.yml" ]; then cp "${MANIFEST_HISTORY_DIR}/2.yml" "${MANIFEST_HISTORY_DIR}/3.yml"; else rm -f "${MANIFEST_HISTORY_DIR}/3.yml"; fi
    if [ -f "${MANIFEST_HISTORY_DIR}/1.yml" ]; then cp "${MANIFEST_HISTORY_DIR}/1.yml" "${MANIFEST_HISTORY_DIR}/2.yml"; else rm -f "${MANIFEST_HISTORY_DIR}/2.yml"; fi
    cp "${ACTIVE_MANIFEST}" "${MANIFEST_HISTORY_DIR}/1.yml"
}

consume_manifest_history() {
    steps="$1"
    case "${steps}" in
        1)
            if [ -f "${MANIFEST_HISTORY_DIR}/2.yml" ]; then mv "${MANIFEST_HISTORY_DIR}/2.yml" "${MANIFEST_HISTORY_DIR}/1.yml"; else rm -f "${MANIFEST_HISTORY_DIR}/1.yml"; fi
            if [ -f "${MANIFEST_HISTORY_DIR}/3.yml" ]; then mv "${MANIFEST_HISTORY_DIR}/3.yml" "${MANIFEST_HISTORY_DIR}/2.yml"; else rm -f "${MANIFEST_HISTORY_DIR}/2.yml"; fi
            rm -f "${MANIFEST_HISTORY_DIR}/3.yml"
            ;;
        2)
            if [ -f "${MANIFEST_HISTORY_DIR}/3.yml" ]; then mv "${MANIFEST_HISTORY_DIR}/3.yml" "${MANIFEST_HISTORY_DIR}/1.yml"; else rm -f "${MANIFEST_HISTORY_DIR}/1.yml"; fi
            rm -f "${MANIFEST_HISTORY_DIR}/2.yml" "${MANIFEST_HISTORY_DIR}/3.yml"
            ;;
        3) rm -f "${MANIFEST_HISTORY_DIR}/1.yml" "${MANIFEST_HISTORY_DIR}/2.yml" "${MANIFEST_HISTORY_DIR}/3.yml" ;;
    esac
}

is_staging_active() { [ -f "${STAGING_STATE_FILE}" ] && grep -qx 'active' "${STAGING_STATE_FILE}" 2>/dev/null; }

staging_ttl_remaining() {
    if [ ! -f "${TTL_FILE}" ]; then echo 0; return; fi
    expiry=$(cat "${TTL_FILE}")
    now=$(date +%s)
    remaining=$(( expiry - now ))
    [ "${remaining}" -gt 0 ] && echo "${remaining}" || echo 0
}

write_state() { mkdir -p "${STAGING_RUNTIME_DIR}"; printf '%s\n' "$1" > "${STAGING_STATE_FILE}"; }
write_ttl_expiry() { mkdir -p "${STAGING_RUNTIME_DIR}"; printf '%d\n' "$1" > "${TTL_FILE}"; }
write_ttl() { write_ttl_expiry "$(( $(date +%s) + $1 * 3600 ))"; }
clear_ttl() { rm -f "${TTL_FILE}"; }

# Absolute expiry currently recorded, or the empty string when no usable TTL is
# recorded, so callers can restore the remaining TTL instead of granting a new one.
read_ttl_expiry() {
    [ -f "${TTL_FILE}" ] || return 0
    expiry=$(cat "${TTL_FILE}" 2>/dev/null || true)
    case "${expiry}" in ''|*[!0-9]*) return 0 ;; esac
    printf '%s\n' "${expiry}"
}

# The lifecycle staging had before the current operation started touching it,
# captured under the lock and before any manifest is deployed.
capture_prior_lifecycle() {
    if is_staging_active; then PRIOR_STATE=active; else PRIOR_STATE=paused; fi
    PRIOR_EXPIRY=$(read_ttl_expiry)
    PRIOR_REMAINING=$(staging_ttl_remaining)
}

# Undo a redeploy that failed or was interrupted, so the recorded state and TTL
# never disagree with the replicas that are actually running and a failed
# attempt never extends the environment's life: an environment that was running
# goes back on its last active manifest with the TTL it had left, and one that
# was paused or expired is stopped again. `paused` is only ever recorded by a
# stop that confirmed it; without that confirmation staging stays `active` so
# the expiry timer keeps retrying.
restore_prior_ttl() {
    if [ -n "${PRIOR_EXPIRY}" ]; then write_ttl_expiry "${PRIOR_EXPIRY}"; else clear_ttl; fi
}

reconcile_prior_lifecycle() {
    restore_prior_ttl
    if [ "${PRIOR_STATE}" = active ] && [ "${PRIOR_REMAINING}" -gt 0 ] && [ -f "${ACTIVE_MANIFEST}" ]; then
        if STAGING_LOCK_HELD=1 "${SCRIPT_DIR}/start.sh" "${ACTIVE_MANIFEST}"; then
            restore_prior_ttl
            log "Restored the last active manifest with the TTL it had left"
            return 0
        fi
        warn "The last active manifest could not be restored"
        restore_prior_ttl
        write_state active
        return 1
    fi
    if [ "${PRIOR_STATE}" = active ]; then
        log "The TTL had already expired; returning staging to paused"
    else
        log "Staging was paused before this operation; returning it to paused"
    fi
    STAGING_LOCK_HELD=1 "${SCRIPT_DIR}/stop.sh" && return 0
    restore_prior_ttl
    write_state active
    return 1
}
