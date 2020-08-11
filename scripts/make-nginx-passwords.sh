#!/bin/bash

set -eo pipefail
export LC_ALL=C
unset CDPATH

THIS_DIR=$( (cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P) )

# Source the config
# shellcheck source=init-env.sh
. "$THIS_DIR/init-env.sh"

usage() {
    echo "Usage: $0 [-h] [ -k KEY_FILE ] [ -c CRT_FILE ] [-f] [-s]" 1>&2
}

fatal() {
    echo >&2 "$*"
    usage
    exit 1
}

if [[ -z "$HTPASSWD_FILE" ]]; then
    fatal "HTPASSWD_FILE variable is not set"
fi

if [[ ( -e "$HTPASSWD_FILE" ) && ( "$1" != "-f" ) ]]; then
    echo >&2 "Error: $HTPASSWD_FILE file(s) already exist !"
    echo >&2 "Delete them or use -f option to overwrite !"
    exit 1
fi

set -x
htpasswd -B -c "$HTPASSWD_FILE" "$PROJECT_NAME"
