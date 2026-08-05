#!/bin/sh
# validate-manifest.sh - validate staging manifest schema without deploying

# shellcheck source=staging/scripts/lib.sh
. "$(dirname "$0")/lib.sh"
[ "$#" -eq 1 ] || die "Usage: validate-manifest.sh <manifest.yml>"
validate_manifest "$1"
log "Manifest is valid"
