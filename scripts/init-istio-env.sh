# shellcheck shell=bash

# Add istio to PATH, to make the istioctl binary easier to use
export ISTIO_DIR=$RESOURCES_DIR/istio
export PATH=$PATH:$ISTIO_DIR/bin

ISTIO_CONFIG_DIR=$ROOT_DIR/src/istio

run-istioctl() {
  "$ISTIO_DIR/bin/istioctl" "${ISTIO_OPTS[@]}" "$@"
}

istio-install() {
  (
    set -xe
    "$ISTIO_DIR/bin/istioctl" "${ISTIO_OPTS[@]}" install "${ISTIO_SETTINGS[@]}" "$@"
  )
}

istio-uninstall() {
  (
    set -xe
    "$ISTIO_DIR/bin/istioctl" "${ISTIO_OPTS[@]}" manifest generate "${ISTIO_SETTINGS[@]}" "$@" | kubectl delete -f - || true;
    kubectl delete namespace istio-system;
  )
}

istio-update() {
  if ! "$SCRIPTS_DIR/download-istio.sh" -C "$RESOURCES_DIR"; then
    echo "Could not download istio" >&2
  else

    # Render configuration
    mo <"${ISTIO_CONFIG_DIR}/nodeport-config.yaml.mustache" >"${ISTIO_CONFIG_DIR}/nodeport-config.yaml"

    define-kubectl-funcs

    KEY_FILE=$ROOT_DIR/src/istio/istio.key
    CRT_FILE=$ROOT_DIR/src/istio/istio.crt
    "$SCRIPTS_DIR/make-cert.sh" -k "$KEY_FILE" -c "$CRT_FILE" -s

    echo "
  Istio is confgured !
  For installing istio configuration run: scripts/istio-install.sh
  For uninstalling istio configuration run: scripts/istio-uninstall.sh
    "
  fi
}
