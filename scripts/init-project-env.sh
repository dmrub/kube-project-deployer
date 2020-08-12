# shellcheck shell=bash

before-start() {
    echo "* Creating project:"
    echo "PROJECT_NAME: $PROJECT_NAME"
    echo "PROJECT_DISPLAYNAME: $PROJECT_DISPLAYNAME"
    echo "PROJECT_DESCRIPTION: $PROJECT_DESCRIPTION"
    echo "PROJECT_REQUESTING_USER: $PROJECT_REQUESTING_USER"
    echo "PROJECT_ADMIN_USER: $PROJECT_ADMIN_USER"
    echo "PROJECT_HOSTNAME: $PROJECT_HOSTNAME"
    echo

    if is-true "$USE_OC_NEW_PROJECT"; then
        if run-oc-ctx get project "$PROJECT_NAME" >& /dev/null; then
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
        if run-oc-ctx get project "$PROJECT_NAME" >& /dev/null; then
            echo "* Deleting OpenShift project $PROJECT_NAME ..."
            run-oc-ctx delete project "$PROJECT_NAME"
        else
            echo "* OpenShift project $PROJECT_NAME does not exist, there is nothing to delete"
        fi
    fi
}
