#!/bin/bash

set -euo pipefail

THIS_DIR=$( (cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P) )

# shellcheck source=init-env.sh
. "$THIS_DIR/init-env.sh"

(set -x;
 istioctl manifest generate --set "profile=${ISTIO_PROFILE}" > "${ISTIO_CONFIG_DIR}/${ISTIO_PROFILE}-manifest.yaml";
 )

# Render configuration
echo "Preprocess ${ISTIO_CONFIG_DIR}/nodeport-config.yaml.mustache -> ${ISTIO_CONFIG_DIR}/nodeport-config.yaml"
mo <"${ISTIO_CONFIG_DIR}/nodeport-config.yaml.mustache" >"${ISTIO_CONFIG_DIR}/nodeport-config.yaml"

set -x
istioctl manifest generate -f "${ISTIO_CONFIG_DIR}/nodeport-config.yaml" > "${ISTIO_CONFIG_DIR}/nodeport-manifest.yaml"
istioctl manifest diff "${ISTIO_CONFIG_DIR}/${ISTIO_PROFILE}-manifest.yaml" "${ISTIO_CONFIG_DIR}/nodeport-manifest.yaml"
