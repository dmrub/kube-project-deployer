#!/bin/bash

IFS=':' read -ra HOST_PORT <<< "$1"

set -xe
echo | \
    openssl s_client -servername "${HOST_PORT[0]}" -connect "${HOST_PORT[0]}:${HOST_PORT[1]}" 2>/dev/null | \
    openssl x509 -text
