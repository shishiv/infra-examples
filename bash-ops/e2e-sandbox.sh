#!/bin/sh
# e2e-sandbox.sh - Run the isolated local E2E sandbox self-test.
#
# This is a local smoke contract for the retained paused-page artifact. It does
# not start staging and never calls Docker, SSH, systemd, GHCR, or GitHub APIs.
# The HTTP server and client both use Python's standard library and bind only
# to loopback inside one disposable process.

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd -P)"
WORKFLOW_DIR="${REPO_ROOT}/github-actions/workflows"
PAUSED_HTML_DIR="${REPO_ROOT}/docker-swarm/staging/paused-html"

SANDBOX_ROOT=""

usage() {
    cat <<'USAGE'
Usage: scripts/e2e-sandbox.sh [--self-test]

Run the isolated local E2E sandbox self-test. The sandbox is disposable,
loopback-only, and does not activate the retained staging contract.
USAGE
}

die() {
    printf '[ERROR] %s\n' "$*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "$1 is required for the E2E sandbox self-test"
}

assert_staging_disabled() {
    [ -d "${WORKFLOW_DIR}" ] || die "GitHub workflow directory is missing: ${WORKFLOW_DIR}"

    for retired_workflow in \
        "${WORKFLOW_DIR}/deploy-staging.yml" \
        "${WORKFLOW_DIR}/deploy-staging.yaml"; do
        [ ! -e "${retired_workflow}" ] || die "staging deploy workflow is present: ${retired_workflow}"
    done

    for workflow in "${WORKFLOW_DIR}"/*.yml "${WORKFLOW_DIR}"/*.yaml; do
        [ -f "${workflow}" ] || continue
        if grep -Eq 'deploy-staging|self-hosted|legacy-provider' "${workflow}"; then
            die "active workflow still contains a retired staging or legacy runner route: ${workflow}"
        fi
    done
}

assert_sandbox_runtime_disabled() {
    for state_file in \
        "${SANDBOX_RUNTIME_DIR}/.staging-state" \
        "${SANDBOX_RUNTIME_DIR}/.staging-ttl" \
        "${SANDBOX_RUNTIME_DIR}/.active-manifest.yml"; do
        [ ! -e "${state_file}" ] || die "staging runtime state appeared in the sandbox: ${state_file}"
    done
}

run_local_http_contract() {
    web_root="$1"
    result_file="$2"

    python3 - "${web_root}" "${result_file}" <<'PY'
import pathlib
import sys
import threading
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from urllib.request import urlopen

web_root = pathlib.Path(sys.argv[1]).resolve()
result_file = pathlib.Path(sys.argv[2])


class QuietRequestHandler(SimpleHTTPRequestHandler):
    """Serve the copied artifact without writing request logs to the test output."""

    def log_message(self, format_string, *args):
        del format_string, args


def handler_factory(*args, **kwargs):
    return QuietRequestHandler(*args, directory=str(web_root), **kwargs)


server = ThreadingHTTPServer(("127.0.0.1", 0), handler_factory)
server.daemon_threads = True
server_thread = threading.Thread(target=server.serve_forever)
server_thread.start()

try:
    bind_address, port = server.server_address
    if bind_address != "127.0.0.1":
        raise RuntimeError("E2E sandbox server was not bound to loopback")

    # A five-second client bound keeps a dead local server from hanging CI.
    with urlopen(f"http://127.0.0.1:{port}/index.html", timeout=5) as response:
        status = response.status
        body = response.read().decode("utf-8")

    if status != 200:
        raise RuntimeError(f"E2E sandbox HTTP status was {status}, expected 200")
    if "<title>Staging Environment Paused</title>" not in body:
        raise RuntimeError("E2E sandbox response did not contain the paused-page title")
    if '<div class="badge">Paused</div>' not in body:
        raise RuntimeError("E2E sandbox response did not contain the paused-page marker")

    result_file.write_text(
        "bind=127.0.0.1\n"
        "path=/index.html\n"
        "status=200\n"
        "body=paused-page\n",
        encoding="utf-8",
    )
finally:
    server.shutdown()
    server.server_close()
    server_thread.join(timeout=5)
PY
}

case "${1:-}" in
    ""|--self-test)
        ;;
    --help|-h)
        usage
        exit 0
        ;;
    *)
        usage >&2
        exit 2
        ;;
esac

require_command mktemp
require_command python3
grep -q '<title>Staging Environment Paused</title>' "${PAUSED_HTML_DIR}/index.html" \
    || die "paused-page artifact is missing: ${PAUSED_HTML_DIR}/index.html"

assert_staging_disabled

umask 077
SANDBOX_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/infra-examples-e2e-sandbox.XXXXXX")"
trap 'if [ -n "${SANDBOX_ROOT}" ]; then rm -rf "${SANDBOX_ROOT}"; fi' EXIT
trap 'exit 130' INT TERM HUP

SANDBOX_RUNTIME_DIR="${SANDBOX_ROOT}/runtime"
SANDBOX_WEB_ROOT="${SANDBOX_ROOT}/web"
SANDBOX_RESULT="${SANDBOX_ROOT}/result"
mkdir -p "${SANDBOX_RUNTIME_DIR}" "${SANDBOX_WEB_ROOT}"

# Copy the real repository artifact into the disposable sandbox. Nothing is
# served from the checkout and no staging runtime directory is consulted.
cp "${PAUSED_HTML_DIR}/index.html" "${SANDBOX_WEB_ROOT}/index.html"
assert_sandbox_runtime_disabled
run_local_http_contract "${SANDBOX_WEB_ROOT}" "${SANDBOX_RESULT}"

[ -f "${SANDBOX_RESULT}" ] || die "E2E sandbox did not produce a result receipt"
grep -Fxq 'bind=127.0.0.1' "${SANDBOX_RESULT}" \
    || die "E2E sandbox result did not prove loopback binding"
grep -Fxq 'path=/index.html' "${SANDBOX_RESULT}" \
    || die "E2E sandbox result did not prove the requested path"
grep -Fxq 'status=200' "${SANDBOX_RESULT}" \
    || die "E2E sandbox result did not prove an HTTP 200 response"
grep -Fxq 'body=paused-page' "${SANDBOX_RESULT}" \
    || die "E2E sandbox result did not prove the paused-page contract"
assert_sandbox_runtime_disabled

printf '%s\n' 'E2E sandbox passed: loopback HTTP contract verified; staging stayed disabled.'
