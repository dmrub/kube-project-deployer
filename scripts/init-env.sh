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

# _RUN_BEFORE_START : List of function names to be executed before start
_RUN_BEFORE_START=()
# _RUN_AFTER_STOP : List of function names to be executed after stop
_RUN_AFTER_STOP=()


before-start-callback-index() {
    echo "${#_RUN_BEFORE_START[@]}"
}

run-before-start-callback() {
    local cb_name
    for cb_name in "${_RUN_BEFORE_START[@]}"; do
        "$cb_name"
    done
}

after-stop-callback-index() {
    echo "${#_RUN_AFTER_STOP[@]}"
}

run-after-stop-callback() {
    local cb_name
    for cb_name in "${_RUN_AFTER_STOP[@]}"; do
        "$cb_name"
    done
}

# load-script loads script with correctly defined THIS_DIR environment variable
load-script() {
    local SCRIPT_FILE=$1 THIS_DIR CB_NAME
    # shellcheck disable=SC2034
    THIS_DIR=$( (cd "$(dirname -- "${SCRIPT_FILE}")" && pwd -P) )
    # shellcheck disable=SC1090
    . "$SCRIPT_FILE"

    # Register callbacks
    if declare -F before-start > /dev/null; then
        # Each config file can define callback with the same name,
        # rename callback function to avoid collisions
        CB_NAME=before-start-$(before-start-callback-index)
        rename-fn before-start "$CB_NAME"
        _RUN_BEFORE_START+=("$CB_NAME")
    fi

    if declare -F after-stop > /dev/null; then
        # Each config file can define callback with the same name,
        # rename callback function to avoid collisions
        CB_NAME=after-stop-$(after-stop-callback-index)
        rename-fn after-stop "$CB_NAME"
        _RUN_AFTER_STOP+=("$CB_NAME")
    fi
}


# http://stackoverflow.com/questions/1203583/how-do-i-rename-a-bash-function
# http://unix.stackexchange.com/questions/29689/how-do-i-redefine-a-bash-function-in-terms-of-old-definition
copy-fn() {
    local fn;
    fn="$(declare -f "$1")" && eval "function $(printf %q "$2") ${fn#*"()"}";
}

rename-fn() {
    copy-fn "$@" && unset -f "$1";
}

is-true() {
    case "$1" in
        true|yes|1) return 0;
    esac
    return 1
}

is-array() {
    declare -p "$1" &>/dev/null && [[ "$(declare -p "$1")" =~ "declare -a" ]]
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
