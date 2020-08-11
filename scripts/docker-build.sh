#!/bin/bash

set -eo pipefail
export LC_ALL=C
unset CDPATH

# shellcheck shell=bash
THIS_DIR=$( (cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P) )

# shellcheck source=init-env.sh
. "$THIS_DIR/init-env.sh"

if [[ "${#GIT_RESOURCES[@]}" -eq 0 ]]; then
    fatal "GIT_RESOURCES variable is empty, check settings.cfg"
fi

if ! command -v docker >/dev/null 2>&1; then
  fatal "docker command is missing"
fi

if is-true "$USE_MINIKUBE"; then
  if ! command -v minikube >/dev/null 2>&1; then
    fatal "minikube command is missing"
  fi
  init-docker() {
    eval "$(minikube docker-env)"
  }
  deinit-docker() {
    eval "$(minikube docker-env -u)"
  }
else
  if [[ ! -x "$RESOURCES_DIR/kube-util/kube-docker-env" ]]; then
    fatal "$RESOURCES_DIR/kube-util/kube-docker-env script is missing"
  fi

  export KUBECTL KUBE_CONTEXT KUBECTL_OPTS
  init-docker() {
    if ! "$RESOURCES_DIR/kube-util/kube-docker-env" >/dev/null; then
      fatal "Could not run kube-docker-env"
    fi
    eval "$("$RESOURCES_DIR/kube-util/kube-docker-env")"
  }
  deinit-docker() {
    if command -v kube-stop-docker >/dev/null 2>&1; then
      kube-stop-docker
    fi
  }
fi

echo "* Initialize docker"

#set -x
init-docker

num_trials=10
delay=1
docker_success=
trial=0
while [[ $trial -lt $num_trials ]]; do
  if docker ps > /dev/null 2>&1; then
    docker_success=true
    break
  fi
  (( trial++ )) || true
  echo "Docker test trial $trial/$num_trials"
  sleep "$delay"
done

if [[ "$docker_success" != "true" ]]; then
  fatal "Could not run remote docker"
fi

trap deinit-docker INT TERM EXIT

for ((i=0;i<${#DOCKER_BUILD[@]};i+=4)); do
  BUILD_DIR=$RESOURCES_DIR/${DOCKER_BUILD[$i]}
  IMAGE_NAME=${DOCKER_BUILD[$i+1]}
  IMAGE_FLAG=${DOCKER_BUILD[$i+2]}
  BUILD_CMD=${DOCKER_BUILD[$i+3]}

  # preprocess variables
  BUILD_DIR=$(printf %s "$BUILD_DIR" | mo)
  IMAGE_NAME=$(printf %s "$IMAGE_NAME" | mo)
  IMAGE_FLAG=$(printf %s "$IMAGE_FLAG" | mo)
  BUILD_CMD=$(printf %s "$BUILD_CMD" | mo)

  if [[ ! -d "$BUILD_DIR" ]]; then
    fatal "Directory $BUILD_DIR does not exist"
  fi

  if [[ -n "$BUILD_CMD" ]]; then
    if ! (
      set -e;
      cd "$BUILD_DIR";
      echo "Build image $IMAGE_NAME in directory $BUILD_DIR";
      echo "Execute: $BUILD_CMD";
      eval "$BUILD_CMD";
    ); then
      fatal "Failed building of image $IMAGE_NAME"
    fi

    if [[ "$IMAGE_FLAG" = "push" ]]; then
      (
        set -e;
        echo "Pushing $IMAGE_NAME";
        set -x;
        docker push "$IMAGE_NAME";
      )
    fi
  fi
done
