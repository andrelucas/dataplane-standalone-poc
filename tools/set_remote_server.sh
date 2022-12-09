#!/bin/bash

function usage() {
    echo "$0 SERVER-IP" >&2
    exit 1
}

if [[ -z "$1" ]]; then
    usage
fi

cat <<EOF
export EXPOSE_CLIENT=true EXPOSE_SERVER=false
export CLIENT_IP_OVERRIDE="" SERVER_IP_OVERRIDE="$1"
EOF
