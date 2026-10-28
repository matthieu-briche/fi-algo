#!/bin/bash
# Usage : qspec.sh [options qspec] fichiers_ou_dossiers_de_specs
TOOLS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export QPATH="$TOOLS/qpath"
exec q "$TOOLS/qspec_boot.q" "$@"