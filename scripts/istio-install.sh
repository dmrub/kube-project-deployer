#!/bin/bash

set -euo pipefail

THIS_DIR=$( (cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P) )

# shellcheck source=init-env.sh
. "$THIS_DIR/init-env.sh"

istio-install "$@"
