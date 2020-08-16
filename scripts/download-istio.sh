#!/bin/sh

# Copyright Istio Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#
# Early version of a downloader/installer for Istio
#
# This file will be fetched as: curl -L https://git.io/getLatestIstio | sh -
# so it should be pure bourne shell, not bash (and not reference other scripts)
#
# The script fetches the latest Istio release candidate and untars it.
# It's derived from ../downloadIstio.sh which is for stable releases but lets
# users do curl -L https://git.io/getLatestIstio | ISTIO_VERSION=0.3.6 sh -
# for instance to change the version fetched.

# This is the latest release candidate (matches ../istio.VERSION after basic
# sanity checks)

set -e

OS="$(uname)"
if [ "x${OS}" = "xDarwin" ] ; then
  OSEXT="osx"
else
  # TODO we should check more/complain if not likely to work, etc...
  OSEXT="linux"
fi

usage() {
    echo "Usage: $0 [-h] [ -C INSTALL_DIR ]" 1>&2
}

fatal() {
    echo >&2 "$*"
    usage
    exit 1
}

INSTALL_DIR=

while getopts ":C:h" OPTIONS; do
    case "${OPTIONS}" in
        C)
            INSTALL_DIR=${OPTARG}
            ;;
        h)
            usage
            exit 0
            ;;
        :)
            fatal "Error: -${OPTARG} requires an argument."
            ;;
        *)
            fatal "Unsupported options: ${OPTIONS}"
            ;;
    esac
done

if [ -n "$INSTALL_DIR" ]; then
  printf "Switch to installation directory %s\n" "$INSTALL_DIR"
  cd "$INSTALL_DIR"
fi

if [ -x "istio/bin/istioctl" ]; then
  printf "istio/bin/istioctl executable already exists, delete %s/istio directory if you want to download it again\n" "$PWD"
  exit 0
fi

if [ "x${ISTIO_VERSION}" = "x" ] ; then
  ISTIO_VERSION=$(curl -L -s https://api.github.com/repos/istio/istio/releases | \
                  grep tag_name | sed "s/ *\"tag_name\": *\"\\(.*\\)\",*/\\1/" | \
		  grep -v -E "(alpha|beta|rc)\.[0-9]$" | sort -t"." -k 1,1 -k 2,2 -k 3,3 -k 4,4 | tail -n 1)
fi

LOCAL_ARCH=$(uname -m)
if [ "${TARGET_ARCH}" ]; then
    LOCAL_ARCH=${TARGET_ARCH}
fi

case "${LOCAL_ARCH}" in
  x86_64)
    ISTIO_ARCH=amd64
    ;;
  armv8*)
    ISTIO_ARCH=arm64
    ;;
  aarch64*)
    ISTIO_ARCH=arm64
    ;;
  armv*)
    ISTIO_ARCH=armv7
    ;;
  amd64|arm64)
    ISTIO_ARCH=${LOCAL_ARCH}
    ;;
  *)
    echo "This system's architecture, ${LOCAL_ARCH}, isn't supported"
    exit 1
    ;;
esac

if [ "x${ISTIO_VERSION}" = "x" ] ; then
  printf "Unable to get latest Istio version. Set ISTIO_VERSION env var and re-run. For example: export ISTIO_VERSION=1.0.4"
  exit 1;
fi

NAME="istio-$ISTIO_VERSION"
URL="https://github.com/istio/istio/releases/download/${ISTIO_VERSION}/istio-${ISTIO_VERSION}-${OSEXT}.tar.gz"
ARCH_URL="https://github.com/istio/istio/releases/download/${ISTIO_VERSION}/istio-${ISTIO_VERSION}-${OSEXT}-${ISTIO_ARCH}.tar.gz"

if [ -d "$NAME" ]; then
  printf "Folder %s already exists, delete if you want to download it again\n" "$NAME"
  rm -f istio
  ln -s "$NAME" istio
  exit 0
fi

printf "Downloading %s from %s ..." "$NAME" "$URL"
if ! curl -fsLO "$URL"
then
  printf "Failed.\n\nTrying with TARGET_ARCH. Downloading %s from %s ...\n" "$NAME" "$ARCH_URL"
  if ! curl -fsLO "$ARCH_URL"
  then
    printf "\n\n"
    printf "Unable to download Istio %s at this moment!\n" "$ISTIO_VERSION"
    printf "Please verify the version you are trying to download.\n\n"
    exit 1
  else
    filename="istio-${ISTIO_VERSION}-${OSEXT}-${ISTIO_ARCH}.tar.gz"
    tar -xzf "${filename}"
    rm "${filename}"
  fi
else
  filename="istio-${ISTIO_VERSION}-${OSEXT}.tar.gz"
  tar -xzf "${filename}"
  rm "${filename}"
fi

if [ ! -d "$NAME" ]; then
  printf "Downloading %s from %s failed" "$NAME" "$URL" >&2
  exit 1
fi

rm -f istio
ln -s "$NAME" istio
printf ""
printf "\nIstio %s Download Complete!\n" "$ISTIO_VERSION"
printf "\n"
printf "Istio has been successfully downloaded into the %s folder on your system.\n" "$NAME"
printf "\n"
BINDIR="$(cd "$NAME/bin" && pwd)"
printf "Next Steps:\n"
printf "See https://istio.io/docs/setup/kubernetes/install/ to add Istio to your Kubernetes cluster.\n"
printf "\n"
printf "To configure the istioctl client tool for your workstation,\n"
printf "add the %s directory to your environment path variable with:\n" "$BINDIR"
printf "\t export PATH=\"\$PATH:%s\"\n" "$BINDIR"
printf "\n"
printf "Begin the Istio pre-installation verification check by running:\n"
printf "\t istioctl verify-install \n"
printf "\n"
printf "Need more information? Visit https://istio.io/docs/setup/kubernetes/install/ \n"
