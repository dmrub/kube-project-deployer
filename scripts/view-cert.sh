#!/bin/bash

set -eo pipefail
export LC_ALL=C
unset CDPATH

THIS_DIR=$( (cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P) )

# Source the config
# shellcheck source=init-env.sh
. "$THIS_DIR/init-env.sh"

openssl x509 -in "${1:-$CERT_CRT_FILE}" -text -noout
