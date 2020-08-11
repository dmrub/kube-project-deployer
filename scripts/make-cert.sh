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

FORCE=
SILENT=

while getopts ":k:c:fsh" OPTIONS; do
    case "${OPTIONS}" in
        f)
            FORCE=yes
            ;;
        s)
            SILENT=yes # don't print error message when key/cert file already exists
            ;;
        k)
            CERT_KEY_FILE=${OPTARG}
            ;;
        c)
            CERT_CRT_FILE=${OPTARG}
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

if [[ ( -e "$CERT_KEY_FILE" || -e "$CERT_CRT_FILE" ) && ( "$FORCE" != "yes" ) ]]; then
    if [[ "$SILENT" != "yes" ]]; then
        echo >&2 "Error: $CERT_KEY_FILE and/or $CERT_CRT_FILE file(s) already exist !"
        echo >&2 "Delete them or use -f option to overwrite !"
        exit 1
    else
        exit 0
    fi
fi

if [[ -z "$CERT_SUBJ_CN" ]]; then
    fatal "CERT_SUBJ_CN variable is not set"
fi
if [[ -z "$CERT_SUBJ_OU" ]]; then
    fatal "CERT_SUBJ_OU variable is not set"
fi
if [[ -z "$CERT_SUBJ_O" ]]; then
    fatal "CERT_SUBJ_O variable is not set"
fi
if [[ -z "$CERT_SUBJ_L" ]]; then
    fatal "CERT_SUBJ_L variable is not set"
fi
if [[ -z "$CERT_SUBJ_ST" ]]; then
    fatal "CERT_SUBJ_ST variable is not set"
fi
if [[ -z "$CERT_SUBJ_C" ]]; then
    fatal "CERT_SUBJ_C variable is not set"
fi
if [[ -z "$CERT_SUBJ_EMAIL" ]]; then
    fatal "CERT_SUBJ_EMAIL variable is not set"
fi

CERT_ALG=${CERT_ALG:-rsa}
CERT_NBITS=${CERT_NBITS:-4096}
CERT_MD=${CERT_MD:-sha256}
CERT_DAYS=${CERT_DAYS:-365}
########################

echo "Generate certificate request with $CERT_ALG:$CERT_NBITS and ${CERT_MD} message digest for ${CERT_DAYS} day(s)"

ALT_NAMES=
for name in "${CERT_SUBJ_ALT_NAMES[@]}"; do
    if [ -n "$ALT_NAMES" ]; then
        ALT_NAMES="${ALT_NAMES}, "
    fi
    ALT_NAMES="${ALT_NAMES}DNS:${name}"
done

# SUBJ="/CN=$CERT_SUBJ_CN/emailAddress=$CERT_SUBJ_EMAIL/OU=$CERT_SUBJ_OU/O=$CERT_SUBJ_O/L=$CERT_SUBJ_L/ST=$CERT_SUBJ_ST/C=$CERT_SUBJ_C"
# -subj "$SUBJ"
#

openssl req -x509 -nodes -days "${CERT_DAYS}" -newkey "$CERT_ALG:$CERT_NBITS" "-${CERT_MD}" \
        -keyout "$CERT_KEY_FILE" -out "$CERT_CRT_FILE" \
        ${ALT_NAMES:+-extensions} ${ALT_NAMES:+subject_alt_name} \
        -config <(
cat <<-EOF
[req]
distinguished_name = dn
prompt = no
${ALT_NAMES:+req_extensions = subject_alt_name}

[ dn ]
C=${CERT_SUBJ_C}
ST=${CERT_SUBJ_ST}
L=${CERT_SUBJ_L}
O=${CERT_SUBJ_O}
OU=${CERT_SUBJ_OU}
emailAddress=${CERT_SUBJ_EMAIL}
CN = ${CERT_SUBJ_CN}

${ALT_NAMES:+[ subject_alt_name ]}
${ALT_NAMES:+subjectAltName = ${ALT_NAMES}}

EOF
)
