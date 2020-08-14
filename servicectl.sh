#!/bin/bash

set -eo pipefail
export LC_ALL=C
unset CDPATH

THIS_DIR=$( (cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P))

# shellcheck source=scripts/init-env.sh
. "$THIS_DIR/scripts/init-env.sh"

define-kubectl-funcs

usage() {
    echo "Control project services"
    echo
    echo "$0 [command]"
    echo "command:"
    echo "  start             start services"
    echo "  stop              stop services"
    echo "  status            print status of services"
    echo "  help              print this"
}


if [[ "${#KUSTOMIZE_DIRS[@]}" -eq 0 ]]; then
    fatal "KUSTOMIZE_DIRS variable is empty, check settings.cfg"
fi

COMMAND=start

if [[ $# -gt 0 ]]; then
    case "$1" in
        start)
            COMMAND=start
            ;;
        stop)
            COMMAND=stop
            ;;
        status)
            COMMAND=status
            ;;
        help|--help)
            usage
            exit
            ;;
        *)
            fatal "Unsupported command: $1"
            ;;
    esac
fi

# Wait for API server to become avilable

echo "* Check availability of the Kubernetes API server ..."
for i in {1..5}; do
    if run-kubectl-ctx version &>/dev/null; then
        break
    else
        echo "* Wait for Kubernetes API server to become available"
        sleep 2
    fi
done
echo "* Kubernetes API server available"

case "$COMMAND" in
    start)
        echo "* Preprocess templates"
        "$SCRIPTS_DIR/preprocess-templates.sh"
        echo ""

        run-before-start-callback

        for kdir in "${KUSTOMIZE_DIRS[@]}"; do
            (
                set -x;
                run-kubectl-ctx apply --record -k "$kdir";
            )
        done
        ;;
    stop)
        for ((i=${#KUSTOMIZE_DIRS[@]}-1; i>=0; i--)); do
            kdir=${KUSTOMIZE_DIRS[$i]}
            (
                set -x;
                run-kubectl-ctx delete -k "$kdir" || true;
            )
        done

        run-after-stop-callback

        ;;
    status)
        if [[ -n "$OPENSHIFT_CLIENT" ]]; then
            echo "* OpenShift status"
            (
                run-oc-ctx status --suggest || true;
            )
            echo;
        fi
        for kdir in "${KUSTOMIZE_DIRS[@]}"; do
            (
                run-kubectl-ctx get -k "$kdir" || true;
            )
        done
        ;;
esac

echo ""

case "$COMMAND" in
    start) echo "All resources deployed." ;;
    stop) echo "All resources stopped." ;;
esac
