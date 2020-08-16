# shellcheck shell=bash

oc-get-project-phase() {
    local phase
    if ! phase=$(run-oc-ctx get project "$1" -o go-template='{{.status.phase}}' 2>/dev/null); then
        return 1
    fi
    echo "$phase"
}

oc-wait-for-project() {
    local phase
    while true; do
        if phase=$(oc-get-project-phase "$1"); then
            if [[ "$phase" == "Active" ]]; then
                echo "$phase"
                return 0
            else
                echo >&2 "* Phase of the OpenShift project $1 is $phase, waiting ..."
                sleep 1
            fi
        else
            echo ""
            return 1
        fi
    done
}

before-start() {
    echo "* Creating project:"
    echo "PROJECT_NAME: $PROJECT_NAME"
    echo "PROJECT_DISPLAYNAME: $PROJECT_DISPLAYNAME"
    echo "PROJECT_DESCRIPTION: $PROJECT_DESCRIPTION"
    echo "PROJECT_REQUESTING_USER: $PROJECT_REQUESTING_USER"
    echo "PROJECT_ADMIN_USER: $PROJECT_ADMIN_USER"
    echo "PROJECT_HOSTNAME: $PROJECT_HOSTNAME"
    echo

    local phase

    if is-true "$USE_OC_NEW_PROJECT"; then
        if ! is-true "$OPENSHIFT_CLIENT"; then
            error "USE_OC_NEW_PROJECT is true, but no OpenShift client was found"
            return 1
        fi
        if phase=$(oc-wait-for-project "$PROJECT_NAME"); then
            echo "* OpenShift project $PROJECT_NAME already exists"
        else
            echo "* Creating OpenShift project $PROJECT_NAME ..."
            run-oc-ctx new-project "$PROJECT_NAME" \
                --display-name="$PROJECT_DISPLAYNAME" \
                --description="$PROJECT_DESCRIPTION"
        fi
    fi
}

after-stop() {
    if is-true "$USE_OC_NEW_PROJECT"; then
        local phase

        if ! is-true "$OPENSHIFT_CLIENT"; then
            error "USE_OC_NEW_PROJECT is true, but no OpenShift client was found"
            return 1
        fi

        if phase=$(oc-wait-for-project "$PROJECT_NAME"); then
            echo "* Deleting OpenShift project $PROJECT_NAME ..."
            run-oc-ctx delete project "$PROJECT_NAME"
        else
            echo "* OpenShift project $PROJECT_NAME does not exist, there is nothing to delete"
        fi
    fi
}
