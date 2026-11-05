#!/bin/bash
# Runs all the specs in tests/; qspec options accepted (e.g. --junit)
cd "$(dirname "${BASH_SOURCE[0]}")"
QSPEC=${QSPEC:-tools/qspec.sh}
exec "$QSPEC" "$@" tests < /dev/null
