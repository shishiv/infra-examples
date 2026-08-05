#!/bin/sh
# runner-bootstrap.sh - Set up a self-hosted CI runner
#
# This historical helper installs and configures a lightweight GitHub Actions
# self-hosted runner. It is not invoked by the active workflows.
#
# Prerequisites:
#   - Ubuntu/Debian
#   - Docker installed
#   - BuildKit enabled (DOCKER_BUILDKIT=1)
#
# Usage: ./runner-bootstrap.sh <github-repo> <runner-token>
#
# Example:
#   ./runner-bootstrap.sh example-org/example-repo <runner-token>

set -eu

[ $# -ge 2 ] || { echo "Usage: $0 <github-repo> <runner-token>" >&2; exit 1; }
REPO="$1"
TOKEN="$2"
RUNNER_DIR="${RUNNER_DIR:-/opt/actions-runner}"
RUNNER_LABEL="${RUNNER_LABEL:-self-hosted-example}"
GITHUB_API_ROOT="${GITHUB_API_ROOT:-https://api.github.com}"
GITHUB_SERVER_ROOT="${GITHUB_SERVER_ROOT:-https://github.com}"

# ── Install dependencies ────────────────────────────────────────────
echo "Installing dependencies..."
apt-get update -qq
apt-get install -y -qq curl jq docker.io

# ── Create runner user ─────────────────────────────────────────────
if ! id -u runner >/dev/null 2>&1; then
    useradd -m -s /bin/bash runner
    usermod -aG docker runner
fi

# ── Download and configure runner ──────────────────────────────────
echo "Setting up GitHub Actions runner..."
mkdir -p "${RUNNER_DIR}"
cd "${RUNNER_DIR}"

# Download latest runner
RUNNER_VERSION=$(curl -s "${GITHUB_API_ROOT}/repos/actions/runner/releases/latest" | jq -r '.tag_name' | sed 's/^v//')
curl -sL "${GITHUB_SERVER_ROOT}/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz" -o runner.tar.gz
tar xzf runner.tar.gz
rm runner.tar.gz

# Configure
./config.sh --url "${GITHUB_SERVER_ROOT}/${REPO}" --token "${TOKEN}" --labels "${RUNNER_LABEL}" --unattended --replace

# ── Install as service ──────────────────────────────────────────────
echo "Installing runner as service..."
./svc.sh install runner
./svc.sh start

echo ""
echo "Self-hosted CI runner setup complete."
echo "  Repository: ${REPO}"
echo "  Labels:     ${RUNNER_LABEL}"
echo "  Service:    actions-runner"
echo ""
echo "Verify with: ${RUNNER_DIR}/svc.sh status (with the required host privileges)"
