# shellcheck shell=bash
SCRIPTS_DIR=$( (cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P) )

ROOT_DIR=$SCRIPTS_DIR/..

# Source shell library
# shellcheck source=shlib.sh
. "$SCRIPTS_DIR/shlib.sh"

# Source mo (mustache preprocessor)
# https://github.com/tests-always-included/mo
# shellcheck source=mo
. "$SCRIPTS_DIR/mo"

# This allows functions referenced in templates to receive additional
# options and arguments. This puts the content from the
# template directly into an eval statement. Use with extreme care.
MO_ALLOW_FUNCTION_ARGUMENTS=1

# The string "false" will be treated as an empty value for the purposes
# of conditionals.
MO_FALSE_IS_EMPTY=1

ifequal() {
    if [[ "$1" = "$2" ]]; then
        cat
    fi
}

ifnotequal() {
    if [[ "$1" != "$2" ]]; then
        cat
    fi
}

# Set array from lines of stdin
# $1 - Destination variable
set-array-from-lines() {
    local line result
    result=()
    while IFS='' read -r line; do result+=("$line"); done
    local "$1" && moIndirectArray "$1" "${result[@]}"
}

# before-start callback is executed before "servicectl start" is executed
declare-callback before-start
# after-stop callback is executed after "servicectl stop" is executed
declare-callback after-stop

# load-script loads script with correctly defined THIS_DIR environment variable
load-script() {
    local script_file=$1 THIS_DIR cb_name
    # shellcheck disable=SC2034
    THIS_DIR=$( (cd "$(dirname -- "${script_file}")" && pwd -P) )
    # shellcheck disable=SC1090
    . "$script_file"

    register-all-callbacks
}

# Set defaults
unset \
    USE_MINIKUBE \
    MINIKUBE \
    MINIKUBE_START_OPTS \
    MINIKUBE_KUBECTL_OPTS \
    MINIKUBE_KUBECTL \
    MINIKUBE_IP

# Load minikube configuration
if [[ -e "$ROOT_DIR/minikube.cfg" ]]; then
    load-script "$ROOT_DIR/minikube.cfg"
fi

: "${USE_MINIKUBE:=false}"

if is-true "$USE_MINIKUBE"; then
    MINIKUBE=${MINIKUBE:-minikube}
    MINIKUBE_KUBECTL_OPTS=${MINIKUBE_KUBECTL_OPTS:-"kubectl -- --context=minikube"}
    MINIKUBE_KUBECTL=${MINIKUBE_KUBECTL:-"minikube"}

    MINIKUBE_IP=could-not-get-minikube-ip

    if ! command -v "$MINIKUBE" >/dev/null 2>&1; then
        error "minikube command ($MINIKUBE) not found"
    else
        if ! MINIKUBE_IP=$("$MINIKUBE" ip); then
            # Start minikube
            (set -xe; "$MINIKUBE" start $MINIKUBE_START_OPTS;)
            # shellcheck disable=SC2034
            if ! MINIKUBE_IP=$("$MINIKUBE" ip); then
                error "Could not get IP of minikube"
            fi
        fi
    fi
fi

# Load configuration
load-script "$ROOT_DIR/settings.cfg"

if is-true "$USE_MINIKUBE"; then
    KUBECTL_OPTS=$MINIKUBE_KUBECTL_OPTS
    KUBECTL=$MINIKUBE_KUBECTL
fi

mkdir -p "$RESOURCES_DIR"

# Init project-related environment
load-script "$SCRIPTS_DIR/init-project-env.sh"
