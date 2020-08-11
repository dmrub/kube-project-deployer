#!/bin/bash

set -eo pipefail
export LC_ALL=C
unset CDPATH

THIS_DIR=$( (cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P))

echo "* Initialize configuration"

# shellcheck source=scripts/init-env.sh
. "$THIS_DIR/scripts/init-env.sh"

echo "* Update resources"
"$THIS_DIR/scripts/update-git-resources.sh"

#echo "* Update istio"
#istio-update

echo "* Render templates"
"$THIS_DIR/scripts/render-templates.sh"

echo "* Finished initialization"
echo "
  For installing istio configuration run: scripts/istio-install.sh
  For uninstalling istio configuration run: scripts/istio-uninstall.sh
  Run ./servicectl.sh for starting services
"
