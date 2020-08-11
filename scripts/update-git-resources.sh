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

for ((i=0;i<${#GIT_RESOURCES[@]};i+=2)); do
  git_dir=$RESOURCES_DIR/${GIT_RESOURCES[$i]}
  git_repo=${GIT_RESOURCES[$i+1]}
  if [[ -d "$git_dir" ]]; then
    echo "* Directory $git_dir exists, trying to update"
    if ! (
      set -xe;
      cd "$git_dir";
      git pull --rebase;
    ); then
      fatal "Could not update repository in directory $git_dir"
    fi
  else
    echo "* Clone $git_repo to directory $git_dir"
    if ! (
      set -xe;
      git clone --recurse-submodules "$git_repo" "$git_dir";
    ); then
      fatal "Could not clone repository $git_repo to directory $git_dir"
    fi
  fi
  echo
done
