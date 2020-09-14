#!/bin/bash

set -eo pipefail

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

is-true() {
    case "$1" in
        true | yes | 1) return 0 ;;
    esac
    return 1
}

is-array() {
    declare -p "$1" &>/dev/null && [[ "$(declare -p "$1")" =~ "declare -a" ]]
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

_ALL_CB=()

declare-callback() {
    if [[ -z "${1:-}" ]]; then
        echo >&2 "No callback name specified"
        return 1
    fi
    local cb_name=$1 cb_var_name sh_code i
    for i in "${_ALL_CB[@]}"; do
        if [[ "$i" == "$cb_name" ]]; then
            # callback was already registered
            return 0
        fi
    done
    _ALL_CB+=("$cb_name")
    cb_var_name=${cb_name^^}
    cb_var_name=_CB_${cb_var_name//[.-]/_}
    printf -v sh_code "
    %s=() # List of function names to be executed
    run-%s-callback() {
        local cb_name
        for cb_name in \"\${%s[@]}\"; do
            \"\$cb_name\" \"\$@\"
        done
    }
    " "$cb_var_name" "$cb_name" "$cb_var_name"
    eval "$sh_code"
}

register-callback() {
    if [[ -z "${1:-}" ]]; then
        echo >&2 "No callback name specified"
        return 1
    fi
    local cb_name=$1 cb_var_name sh_code num_cb new_cb_name
    cb_var_name=${cb_name^^}
    cb_var_name=_CB_${cb_var_name//[.-]/_}
    if declare -F "$cb_name" > /dev/null; then
        # Each config file can define callback with the same name,
        # rename callback function to avoid collisions
        eval "num_cb=\${#${cb_var_name}[@]}"
        new_cb_name=$cb_name-$num_cb
        rename-fn "$cb_name" "$new_cb_name"
        eval "${cb_var_name}+=(\"$new_cb_name\")"
    fi
}

register-all-callbacks() {
    local cb_name
    for cb_name in "${_ALL_CB[@]}"; do
        register-callback "$cb_name"
    done
}

# Define kubectl-related functions
define-kubectl-funcs() {
    case "$(uname)" in
        MINGW* | CYGWIN*)
           KUBECTL_EXE=kubectl.exe
           OC_EXE=oc.exe
           ;;
        *)
           # shellcheck disable=2034
           KUBECTL_EXE=kubectl
           # shellcheck disable=2034
           OC_EXE=oc
           ;;
    esac

    if [[ -n "${TEST_KUBECTL:-}" ]]; then
        KUBECTL=${TEST_KUBECTL}   # substitute for tests
    elif [[ -n "${KUBECTL_BIN:-}" ]]; then
        KUBECTL=${KUBECTL_BIN}
    elif [[ -z "${KUBECTL:-}" ]]; then
        KUBECTL=$(command -v kubectl || true)
        if [[ -z "${KUBECTL:-}" ]]; then
            KUBECTL=$(command -v oc || true)
        fi
    fi

    if [[ ! -x "${KUBECTL:-}" ]]; then
        KUBECTL=$(command -v "${KUBECTL:-}" || true)
    fi

    if [[ ! -x "${KUBECTL:-}" ]]; then
        if [[ -n "${KUBECTL:-}" ]]; then
            fatal "kubectl command ${KUBECTL} not found or is not executable"
        else
            fatal "kubectl command is not found"
        fi
    fi

    # check if kubectl is OpenShift client

    # disabling pipefail required because grep will stop after first match
    # https://stackoverflow.com/questions/19120263/why-exit-code-141-with-grep-q
    set +o pipefail
    if "${KUBECTL}" --help 2>&1 | grep -qi openshift; then
        OPENSHIFT_CLIENT=true
        OC=$KUBECTL
    else
        # shellcheck disable=SC2034
        OPENSHIFT_CLIENT=
        OC=
    fi
    set -o pipefail

    KUBECTL_OPTS=${KUBECTL_OPTS:-}

    run-kubectl() {
        # shellcheck disable=2086
        "${KUBECTL}" ${KUBECTL_OPTS} "$@"
    }

    run-oc() {
        # shellcheck disable=2086
        "${OC}" ${KUBECTL_OPTS} "$@"
    }

    # Run kubernetes with configured context
    run-kubectl-ctx() {
        local opts=()
        if [[ -n "$KUBE_CONTEXT" ]]; then
            opts+=(--context "$KUBE_CONTEXT")
        fi
        run-kubectl "${opts[@]}" "$@"
    }

    # Run kubernetes with configured context
    run-oc-ctx() {
        local opts=()
        if [[ -n "$KUBE_CONTEXT" ]]; then
            opts+=(--context "$KUBE_CONTEXT")
        fi
        run-oc "${opts[@]}" "$@"
    }

    kube-current-context() {
        run-kubectl-ctx config view --minify -o=jsonpath='{.current-context}'
    }

    kube-current-namespace() {
        local ns
        # local cur_ctx ns
        #cur_ctx=$(kube-current-context)
        #ns=$(run-kubectl-ctx config view -o=jsonpath="{.contexts[?(@.name==\"${cur_ctx}\")].context.namespace}")
        ns=$(run-kubectl-ctx config view --minify --output 'jsonpath={..namespace}')
        if [[ -z "${ns}" ]]; then
            echo "default"
        else
            echo "${ns}"
        fi
    }

    kube-current-server() {
        run-kubectl-ctx config view --minify -o=jsonpath='{..server}'
    }

    kube-set-namespace() {
        local ctx
        ctx=$(kube-current-context)
        run-kubectl-ctx config set-context "${ctx}" --namespace="${1}"
    }

    kube-server-version() {
        local server_version major minor patch
        server_version=$(run-kubectl-ctx --match-server-version=false version | grep "Server Version:")
        echo "${server_version}" | \
                sed -E "s/.*GitVersion:\"(v([0-9]+)\.([0-9]+)\.([0-9]+)).*/\1/"
    }

    # kubectl version | grep "Server Version:"  | sed -E "s/.*GitVersion:\"v([0-9]+)\.([0-9]+)\.([0-9]+).*/\1 \2 \3/"
    kube-server-version-as-int() {
        local server_version major minor patch
        server_version=$(run-kubectl-ctx --match-server-version=false | grep "Server Version:")
        read -r major minor patch < <(
                echo "${server_version}" | \
                sed -E "s/.*GitVersion:\"v([0-9]+)\.([0-9]+)\.([0-9]+).*/\1 \2 \3/")
        printf "%02d%02d%02d" "${major}" "${minor}" "${patch}" | sed 's/^0*//'
    }
}

# Define path-related functions and variables
# SED_NOCR_OPT : option to disable conversion of line endings to Unix
# NAT_PATHSEP  : the character used by the operating system to separate
#                search path components (as in PATH)
# NAT_SEP      : the character used by the operating system to separate
#                pathname components.
# natpath      : convert Unix path to native (Windows) path
# unixpath     : convert native (Windows) path to Unix path
define-path-funcs() {
    case "$(uname)" in
        CYGWIN*)
            SED_NOCR_OPT=--binary
            natpath() {
                if [[ -z "$1" ]]; then
                    echo "$*"
                else
                    cygpath -w "$*"
                fi
            }
            unixpath() {
                if [[ -z "$1" ]]; then
                    echo "$*"
                else
                    cygpath -u "$*"
                fi
            }
            NAT_PATHSEP=";"
            NAT_SEP="\\"
            ;;
        MINGW*)
            # check option to disable conversion of line endings to Unix
            if echo 'X' | sed --nocr 's|X|Y|' &>/dev/null; then
                SED_NOCR_OPT=--nocr
            else
                SED_NOCR_OPT=--binary
            fi
            natpath() {
                if [[ -z "$1" ]]; then
                    echo "$*"
                else
                    if [[ -f "$1" ]]; then
                        local dir fn
                        dir=$(dirname "$1")
                        fn=$(basename "$1")
                        echo "$(cd "$dir"; echo "$(pwd -W)/$fn")" | sed 's|/|\\|g';
                    else
                        if [[ -d "$1" ]]; then
                            echo "$(cd "$1" && pwd -W)" | sed 's|/|\\|g'
                        else
                            echo "$1" | sed 's|^/\(.\)/|\1:\\|g; s|/|\\|g'
                        fi
                    fi
                fi
            }
            unixpath() {
                if [[ -z "$1" ]]; then
                    echo "$*"
                else
                    echo "$1" | sed -e 's|^\(.\):|/\1|g' -e 's|\\|/|g'
                fi
            }
            NAT_PATHSEP=";"
            NAT_SEP="\\"
            ;;
        *)
            natpath() { echo "$*"; }
            unixpath() { echo "$*"; }
            # shellcheck disable=2034
            SED_NOCR_OPT=
            # shellcheck disable=2034
            NAT_PATHSEP=":"
            # shellcheck disable=2034
            NAT_SEP="/"
            ;;
    esac
}


# https://www.linuxjournal.com/content/normalizing-path-names-bash

normpath() {
    # Remove all /./ sequences.
    local path=${1//\/.\//\/}

    # Remove dir/.. sequences.
    while [[ $path =~ ([^/][^/]*/\.\./) ]]; do
        path=${path/${BASH_REMATCH[0]}/}
    done
    echo "$path"
}

if test -x /usr/bin/realpath; then
    abspath() {
        if [[ -d "$1" || -d "$(dirname "$1")" ]]; then
            /usr/bin/realpath "$1"
        else
            case "$1" in
                "" | ".") echo "$PWD";;
                /*) normpath "$1";;
                *)  normpath "$PWD/$1";;
            esac
        fi
    }
else
    abspath() {
        if [[ -d "$1" ]]; then
            (cd "$1" || exit 1; pwd)
        else
            case "$1" in
                "" | ".") echo "$PWD";;
                /*) normpath "$1";;
                *)  normpath "$PWD/$1";;
            esac
        fi
    }
fi


# [options] pod_name_prefix
# options ::=
# -n, --namespace  NS  (default default)
#     --num-checks N   (default 5)
#     --delay      sec (default 2)
#     --debug
#     --           end of options
wait-for-pod() {
    local num_run_checks=5 num_trials=0 delay=2 pod_ns debug_flag cur_ns
    pod_ns=$(kube-current-namespace)

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help)
                cat <<EOF
$0 [options] pod_name_prefix

Wait until Kubernetes pod runs with the name starting with pod_name_prefix.

-n | --namespace  NAMESPACE  Set pod namespace (default: $pod_ns)
     --trials     N          Number of trials (0 - infinite, default: $num_trials)
     --run-checks N          Number of checks to perform until pod is assumed to be running (default: $num_run_checks)
     --delay      SECONDS    Delay in seconds between checks (default: $delay)
     --debug                 Enable debug output
EOF
                return 0
                ;;
            -n|--namespace)
                pod_ns="$2"
                shift 2
                ;;
            --trials)
                num_trials="$2"
                shift 2
                ;;
            --run-checks)
                num_run_checks="$2"
                shift 2
                ;;
            --delay)
                delay="$2"
                shift 2
                ;;
            --debug)
                debug_flag=true
                shift
                ;;
            --)
                shift
                break
                ;;
            -*)
                echo >&2 "$0: error: unknown option $1"
                return 1
                ;;
            *)
                break
                ;;
        esac
    done

    local pod_name_prefix=$1
    local pod_name running check trial i phase
    declare -a ns_opt pod_names

    if [[ -z "$pod_ns" ]]; then
        ns_opt=(--namespace default)
    else
        ns_opt=(--namespace "$pod_ns")
    fi

    [[ "$debug_flag" = "true" ]] && message "[wait-for-pod] namespace option : ${ns_opt[*]}"

    trial=0
    running=false
    while ! $running; do
        [ "$debug_flag" = "true" ] && message "[wait-for-pod] Waiting for '$pod_name_prefix' pod ..."

        if ! pod_names=( $(run-kubectl-ctx get pods "${ns_opt[@]}" -o go-template='{{range.items}} {{ .metadata.name }} {{ .metadata.namespace }}{{end}}') ); then
            return 1
        fi

        if [[ ${#pod_names[@]} -eq 0 && $num_run_checks -eq 0 ]]; then
            break
        fi

        [ "$debug_flag" = "true" ] && message "[wait-for-pod] pod_names: ${pod_names[*]}"

        for ((i = 0; i < ${#pod_names[@]}; i += 2)); do
            pod_name=${pod_names[i]}
            pod_ns=${pod_names[i + 1]}

            if [[ "$pod_name" == "$pod_name_prefix"* ]]; then
                [ "$debug_flag" = "true" ] && message "[wait-for-pod] Found pod $pod_name"
                running=false
                check=0
                while true; do
                    if phase=$(run-kubectl-ctx get pod --namespace="$pod_ns" "$pod_name" -o go-template='{{ .status.phase }}'); then
                        [ "$debug_flag" = "true" ] && message "[wait-for-pod] Pod $pod_name in phase $phase [$((check + 1))/$num_run_checks]"
                        case "$phase" in
                            Running)
                                running=true
                                (( check++ )) || true
                                if [[ $check -ge $num_run_checks ]]; then
                                    break
                                fi
                                ;;
                            Failed | Error)
                                running=false
                                check=0
                                run-kubectl-ctx delete pod --namespace="$pod_ns" "$pod_name"
                                break
                                ;;
                            *)
                                running=false
                                check=0
                                ;;
                        esac
                    else
                        running=false
                        check=0
                        break
                    fi
                    sleep "$delay"
                done
                if $running; then
                    [[ "$debug_flag" = "true" ]] && message "[wait-for-pod] Pod $pod_name running, exiting."
                    echo "$pod_name"
                    return 0
                fi
            fi
        done
        if [[ $num_trials -gt 0 ]]; then
            (( trial++ )) || true
            if [[ $trial -ge $num_trials ]]; then
                break
            fi
            [ "$debug_flag" = "true" ] && message "[wait-for-pod] Trial $trial/$num_trials"
        fi
        sleep "$delay"
    done
    return 1
}

match-pod() {
    wait-for-pod --run-checks 1 --trials 1 --delay 0 "$@"
}

# Template Preprocessor

define-template-preprocessor-funcs() {

    : "${TEMPLATE_OVERWRITE:=true}"

    preprocess-filename() {
        # By default don't change file name
        echo "$1"
    }

    action-preprocess() {
        local dest_file
        case "$SRC_FILE" in
            *.mustache)
                # remove mustache
                dest_file=${SRC_FILE%.*}
                # preprocess filename
                dest_file=$(preprocess-filename "$dest_file")
                echo "In $SRC_FILE_DIR: preprocess $FILE_BN -> $DEST_DIR/$dest_file"
                if [[ -e "$DEST_DIR/$dest_file" ]] && ! is-true "$TEMPLATE_OVERWRITE"; then
                    fatal "File $DEST_DIR/$dest_file already exists and overwriting is disabled, abort the action"
                fi
                mo <"$SRC_FILE" >"$DEST_DIR/$dest_file"
                ;;
            *)
                fatal "Unknown file extension $FILE_EXT in $SRC_FILE"
                ;;
        esac
    }

    action-copy-file() {
        local dest_file
        dest_file=$SRC_FILE
        dest_file=$(preprocess-filename "$dest_file")
        echo "In $SRC_FILE_DIR: copy $FILE_BN -> $DEST_DIR/$dest_file"
        if [[ -e "$DEST_DIR/$dest_file" ]] && ! is-true "$TEMPLATE_OVERWRITE"; then
            fatal "File $DEST_DIR/$dest_file already exists and overwriting is disabled, abort the action"
        fi
        cp -a "$SRC_FILE" "$DEST_DIR/$dest_file"
    }

    preprocess-templates() {
        if [[ -z "$TEMPLATE_DEST_DIR" ]]; then
            fatal "TEMPLATE_DEST_DIR variable is not set"
        fi

        dest_dir=$(abspath "$TEMPLATE_DEST_DIR")
        echo "Create template destination directory $dest_dir"
        mkdir -p "$dest_dir"

        echo "Preprocessing templates in $TEMPLATE_SRC_DIR ..."
        cd "$TEMPLATE_SRC_DIR"
        while IFS= read -r -d '' file; do
            # Ignore source directory
            if [[ "$file" = "." ]]; then
                continue
            fi

            # Create directory
            if [[ -d "$file" ]]; then
                if [[ ! -d "$dest_dir/$file" ]]; then
                    echo "Create directory $dest_dir/$file"
                    mkdir -p "$dest_dir/$file"
                fi
                continue
            fi

            file_action=
            case "$file" in
                *.mustache) file_action="action-preprocess" ;;
                *) file_action="action-copy-file" ;;
            esac

            file_to_match=${file#"."}
            for ((i = 0; i < ${#TEMPLATE_FILE_ACTIONS[@]}; i += 2)); do
                pat=${TEMPLATE_FILE_ACTIONS[$i]}
                action=${TEMPLATE_FILE_ACTIONS[$i + 1]}
                if [[ -n "$pat" ]]; then
                    # shellcheck disable=SC2053
                    if [[ "$file_to_match" = $pat ]]; then
                        case "$action" in
                            ignore) file_action="" ;;
                            copy) file_action="action-copy-file" ;;
                            preprocess) file_action="action-preprocess" ;;
                            *) fatal "Unknown file action $action in TEMPLATE_FILE_ACTIONS variable" ;;
                        esac
                        break
                    fi
                fi
            done

            SRC_FILE=$file
            DEST_DIR=$dest_dir
            SRC_FILE_DIR=$( (cd "$(dirname -- "$SRC_FILE")" && pwd -P))
            FILE_BN=$(basename -- "$SRC_FILE")
            FILE_EXT=${FILE_BN##*.}
            # shellcheck disable=SC2034
            FILE_FN="${FILE_BN%.*}"

            if [[ -n "$file_action" ]]; then
                "$file_action"
            fi

        done < <(find "." -print0)
    }
}
