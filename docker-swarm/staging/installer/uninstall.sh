#!/bin/sh
# uninstall.sh - Remove this infrastructure example from a Swarm manager
#
# Usage: sudo ./uninstall.sh
#   Must be run as root on the Docker Swarm manager node.

set -eu

INSTALL_DIR="${INSTALL_DIR:-/opt/portfolio-infra}"
SYSTEMD_DIR="/etc/systemd/system"

[ "$(id -u)" -eq 0 ] || { echo "ERROR: uninstall.sh must be run as root" >&2; exit 1; }

echo "WARNING: This will remove the portfolio infrastructure example."
echo "The staging Docker stack will be removed."
printf "Continue? [y/N] "
read -r confirm
[ "${confirm}" = "y" ] || [ "${confirm}" = "Y" ] || { echo "Aborted."; exit 0; }

# ── Stop staging ───────────────────────────────────────────────────
echo "Stopping staging environment..."
if command -v docker >/dev/null 2>&1; then
    docker stack rm staging 2>/dev/null || echo "  (staging stack not found)"
fi

# ── Disable and stop systemd units ─────────────────────────────────
echo "Disabling systemd units..."
systemctl stop staging-expiry-check.timer 2>/dev/null || true
systemctl disable staging-expiry-check.timer 2>/dev/null || true

# ── Remove systemd files ───────────────────────────────────────────
echo "Removing systemd files..."
rm -f "${SYSTEMD_DIR}/staging-expiry-check.service"
rm -f "${SYSTEMD_DIR}/staging-expiry-check.timer"
systemctl daemon-reload

# ── Remove installation directory ───────────────────────────────────
echo "Removing ${INSTALL_DIR}..."
rm -rf "${INSTALL_DIR}"

echo "Uninstall complete."
