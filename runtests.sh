#!/bin/bash
# Lance toutes les specs de tests/ ; options qspec acceptées (ex. --junit)
cd "$(dirname "${BASH_SOURCE[0]}")"
QSPEC=${QSPEC:-../tools/qspec.sh}
exec "$QSPEC" "$@" tests < /dev/null
