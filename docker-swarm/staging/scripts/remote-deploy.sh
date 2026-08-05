#!/bin/sh
# remote-deploy.sh - fixed SSH forced-command protocol for one manifest

# shellcheck source=staging/scripts/lib.sh
. "$(dirname "$0")/lib.sh"

umask 077
IFS= read -r protocol || die "Remote deploy payload is empty"
[ "${protocol}" = "PORTFOLIO-DEPLOY-V1" ] || die "Unsupported remote deploy protocol"
IFS= read -r token || die "Remote deploy payload is missing the registry token"
[ -n "${token}" ] || die "Remote deploy payload contains an empty registry token"

manifest=$(mktemp)
cleanup_remote_deploy() {
    unset REGISTRY_TOKEN token
    rm -f "${manifest}"
}
trap cleanup_remote_deploy EXIT INT TERM
cat > "${manifest}"
REGISTRY_TOKEN="${token}"; export REGISTRY_TOKEN
"${SCRIPT_DIR}/deploy.sh" "${manifest}"
