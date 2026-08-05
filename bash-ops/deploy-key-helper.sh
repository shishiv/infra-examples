#!/bin/sh
# deploy-key-helper.sh - Generate a forced-command deploy key
#
# This historical helper generates an SSH key pair and prints the
# authorized_keys line for the target automation account.
#
# The forced command ignores all requested commands and accepts only the
# versioned deployment payload on stdin.
#
# Usage: ./deploy-key-helper.sh [key_name]
#   Default key name: portfolio-deploy-key

set -eu

key_name="${1:-portfolio-deploy-key}"
key_dir="${HOME}/.ssh"
module_install_dir="${MODULE_INSTALL_DIR:-/opt/portfolio-infra}"
deploy_user="${DEPLOY_USER:-runner}"
key_comment="${KEY_COMMENT:-portfolio-deploy@example.invalid}"

mkdir -p "${key_dir}"

echo "Generating deploy key: ${key_name}"
ssh-keygen -t ed25519 -f "${key_dir}/${key_name}" -N "" -C "${key_comment}" 2>&1

echo ""
echo "=== Public Key ==="
echo ""
cat "${key_dir}/${key_name}.pub"
echo ""
echo "=== Authorized Keys Entry (add to the target account's authorized_keys) ==="
echo ""
echo "Target account: ${deploy_user}"
echo "command=\"${module_install_dir}/staging/scripts/remote-deploy.sh\",no-agent-forwarding,no-port-forwarding,no-pty,no-user-rc,no-X11-forwarding $(cat "${key_dir}/${key_name}.pub")"
echo ""
echo "=== Private Key (save as a CI secret) ==="
echo ""
cat "${key_dir}/${key_name}"
echo ""
echo "Done. Key pair saved to:"
echo "  Private: ${key_dir}/${key_name}"
echo "  Public:  ${key_dir}/${key_name}.pub"
