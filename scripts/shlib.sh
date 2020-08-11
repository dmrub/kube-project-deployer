# shellcheck shell=bash
# global config

if [[ -n "$TEST_KUBECTL" ]]; then
    KUBECTL=${TEST_KUBECTL}   # substitute for tests
elif [[ -n "$KUBECTL_BIN" ]]; then
    KUBECTL=${KUBECTL_BIN}
elif [[ -z "$KUBECTL" ]]; then
    KUBECTL=$(type -p kubectl)
fi

if [[ ! -x "${KUBECTL}" ]]; then
    KUBECTL=$(type -p "${KUBECTL}")
fi

if [[ ! -x "${KUBECTL}" ]]; then
    echo >&2 "ERROR: kubectl command (${KUBECTL}) not found or is not executable"
    exit 1
fi

KUBECTL_OPTS=${KUBECTL_OPTS:-}
PYTHON=${PYTHON:-python}

msg() {
    echo >&2 "$*"
}

run-kubectl() {
    echo >&2 "+ ${KUBECTL} ${KUBECTL_OPTS} $*"
    "${KUBECTL}" ${KUBECTL_OPTS} "$@"
}

error() {
    echo >&2 "Error: $*"
}

fatal() {
    echo >&2 "Fatal: $*"
    exit 1
}
