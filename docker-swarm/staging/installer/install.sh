#!/bin/sh
# install.sh - Install this infrastructure example on a Swarm manager
#
# This script:
#   1. Copies the module to /opt/portfolio-infra/
#   2. Installs systemd units and timers
#   3. Creates required directories and sets permissions
#   4. Validates the installation
#
# Usage: sudo ./install.sh
#   Must be run as root on the Docker Swarm manager node.

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
STAGING_SRC="$(cd "${SCRIPT_DIR}/.." && pwd -P)"
MODULE_SRC="$(cd "${STAGING_SRC}/.." && pwd -P)"
INSTALL_DIR="${INSTALL_DIR:-/opt/portfolio-infra}"
SYSTEMD_DIR="/etc/systemd/system"

# ── Prerequisites ──────────────────────────────────────────────────
[ "$(id -u)" -eq 0 ] || { echo "ERROR: install.sh must be run as root" >&2; exit 1; }

command -v docker >/dev/null 2>&1 || { echo "ERROR: docker is required" >&2; exit 1; }
command -v systemctl >/dev/null 2>&1 || { echo "ERROR: systemctl is required" >&2; exit 1; }

# ── Create directories ────────────────────────────────────────────
echo "Creating directories..."
mkdir -p "${INSTALL_DIR}"
mkdir -p "${INSTALL_DIR}/staging/scripts"
mkdir -p "${INSTALL_DIR}/staging/paused-html"
mkdir -p "${INSTALL_DIR}/staging/systemd"

# ── Copy files ─────────────────────────────────────────────────────
echo "Copying staging infrastructure to ${INSTALL_DIR}..."
cp -r "${STAGING_SRC}/stack.yml" "${INSTALL_DIR}/staging/"
cp -r "${STAGING_SRC}/deploy-manifest.yml" "${INSTALL_DIR}/staging/"
cp -r "${STAGING_SRC}/paused-html/"* "${INSTALL_DIR}/staging/paused-html/"
cp -r "${STAGING_SRC}/scripts/"*.sh "${INSTALL_DIR}/staging/scripts/"
cp -r "${MODULE_SRC}/.env.example" "${INSTALL_DIR}/"
cp -r "${STAGING_SRC}/systemd/"*.service "${SYSTEMD_DIR}/"
cp -r "${STAGING_SRC}/systemd/"*.timer "${SYSTEMD_DIR}/"

# ── Set permissions ────────────────────────────────────────────────
echo "Setting permissions..."
chown -R runner:runner "${INSTALL_DIR}" 2>/dev/null || chown -R root:root "${INSTALL_DIR}"
chmod 755 "${INSTALL_DIR}/staging/scripts/"*.sh
chmod 644 "${SYSTEMD_DIR}/staging-expiry-check.service"
chmod 644 "${SYSTEMD_DIR}/staging-expiry-check.timer"

# ── Reload systemd ─────────────────────────────────────────────────
echo "Reloading systemd..."
systemctl daemon-reload

# ── Enable and start timer ─────────────────────────────────────────
echo "Enabling staging expiry check timer..."
systemctl enable staging-expiry-check.timer
systemctl start staging-expiry-check.timer

# ── Validate installation ──────────────────────────────────────────
echo ""
echo "=== Installation Validation ==="

errors=0
for f in \
    "${INSTALL_DIR}/staging/stack.yml" \
    "${INSTALL_DIR}/staging/deploy-manifest.yml" \
    "${INSTALL_DIR}/staging/scripts/start.sh" \
    "${INSTALL_DIR}/staging/scripts/stop.sh" \
    "${INSTALL_DIR}/staging/scripts/status.sh" \
    "${INSTALL_DIR}/staging/scripts/deploy.sh" \
    "${INSTALL_DIR}/staging/scripts/extend-ttl.sh" \
    "${INSTALL_DIR}/staging/scripts/check-expiry.sh" \
    "${INSTALL_DIR}/staging/scripts/rollback.sh" \
    "${INSTALL_DIR}/staging/scripts/smoke-test.sh" \
    "${INSTALL_DIR}/staging/scripts/preflight.sh" \
    "${INSTALL_DIR}/staging/scripts/drift-report.sh" \
    "${INSTALL_DIR}/staging/scripts/reset-synthetic.sh" \
    "${INSTALL_DIR}/staging/scripts/remote-deploy.sh" \
    "${INSTALL_DIR}/staging/scripts/validate-manifest.sh" \
    "${INSTALL_DIR}/staging/scripts/lib.sh" \
    "${INSTALL_DIR}/.env.example" \
    "${SYSTEMD_DIR}/staging-expiry-check.service" \
    "${SYSTEMD_DIR}/staging-expiry-check.timer"; do
    if [ -f "${f}" ]; then
        echo "  [OK] ${f}"
    else
        echo "  [MISSING] ${f}"
        errors=$(( errors + 1 ))
    fi
done

if [ "${errors}" -gt 0 ]; then
    echo "ERROR: ${errors} file(s) missing after installation" >&2
    exit 1
fi

echo ""
echo "Installation complete."
echo ""
echo "Next steps:"
echo "  1. Configure the module: cp ${INSTALL_DIR}/.env.example ${INSTALL_DIR}/.env"
echo "  2. Set the expected edge IP and network names (never persist REGISTRY_TOKEN)"
echo "  3. Verify timer: systemctl status staging-expiry-check.timer"
echo "  4. Staging deployment workflow is retired; no CI deployment is configured"
