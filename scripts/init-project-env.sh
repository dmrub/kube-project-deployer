# shellcheck shell=bash

before-start() {
    echo "Creating project:"
    echo "PROJECT_NAME: $PROJECT_NAME"
    echo "PROJECT_DISPLAYNAME: $PROJECT_DISPLAYNAME"
    echo "PROJECT_DESCRIPTION: $PROJECT_DESCRIPTION"
    echo "PROJECT_REQUESTING_USER: $PROJECT_REQUESTING_USER"
    echo "PROJECT_ADMIN_USER: $PROJECT_ADMIN_USER"
    echo "PROJECT_HOSTNAME: $PROJECT_HOSTNAME"
    echo

    if is-true "$USE_OC_NEW_PROJECT" && ! run-oc-ctx get project "$PROJECT_NAME" >& /dev/null; then
        echo "Creating OpenShift project..."
        run-oc-ctx new-project "$PROJECT_NAME" \
            --display-name="$PROJECT_DISPLAYNAME" \
            --description="$PROJECT_DESCRIPTION"
    fi
}

after-stop() {
    echo "Deleting OpenShift project..."

    if is-true "$USE_OC_NEW_PROJECT" && run-oc-ctx get project "$PROJECT_NAME" >& /dev/null; then
        run-oc-ctx delete project "$PROJECT_NAME"
    fi
}
