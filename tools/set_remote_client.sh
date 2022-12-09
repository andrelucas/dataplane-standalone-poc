#!/bin/bash

function usage() {
    echo "$0 CLIENT-IP" >&2
    exit 1
}

if [[ -z "$1" ]]; then
    usage
fi

cat <<EOF
export EXPOSE_CLIENT=false EXPOSE_SERVER=true
export CLIENT_IP_OVERRIDE="$1" SERVER_IP_OVERRIDE=""
EOF
