#!/bin/bash

set -eo pipefail
export LC_ALL=C
unset CDPATH

THIS_DIR=$( (cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P) )

error() {
    echo >&2 "Error: $*"
}

fatal() {
    error "$@"
    exit 1
}

message() {
    echo >&2 "$*"
}

if [[ -z "$KUBECTL" ]]; then
    KUBECTL=$(command -v oc)
    if [[ -z "$KUBECTL" ]]; then
        KUBECTL=$(command -v kubectl)
    fi
fi

if [[ -z "$KUBECTL" ]]; then
    fatal "Could find neither oc nor kubectl tool in PATH"
fi

message "I will use $KUBECTL as Kubernetes CLI tool"
KUBECTX=$("$KUBECTL" config view --minify -o=jsonpath='{.current-context}')
message "Current Kubernetes context is '$KUBECTX'"
message "Add or replace the following lines in the settings.cfg file:"

echo "
# Kubectl configuration
export KUBECTL_OPTS=\"--context=$KUBECTX\"
export KUBECTL=\"$KUBECTL\"
"
