#!/bin/bash

# Generate runtime configuration that's copied into the node containers so
# they can finalise their configuration before running tests.

set -e

# All diagnostics must go to stderr, stdout is used for the resulting env file.

function error() {
    echo "ERROR: $*" >&2
    exit 1
}

function info() {
    echo "-- $*" >&2
}

function debug() {
    if [[ $env_debug = 1 ]]; then
        echo "++ $*" >&2
    fi
}

function usage() {
    echo "Usage: $0 -d [-b BRANCH_HASH] [-c CLUSTER_ID] [-f TEST_FILTER] [-g TEST_GROUP] [-C CLIENT_IP_OVERRIDE] [-S SERVER_IP_OVERRIDE] [-P REMOTE_SSH_PORT] CLIENT_CONTAINER_ID SERVER_CONTAINER_ID" >&2
    exit 1
}

branch_hash=deadbeef
client_ip_override=NONE
cluster_id=local
env_debug=0
server_ip_override=NONE
remote_ssh_port=22
test_group=NONE
test_filter=NONE

while getopts "C:P:S:b:c:df:g:" opt; do
    case "${opt}" in
    C)
        if [[ $OPTARG != "" ]]; then
            client_ip_override=$OPTARG
        fi
        ;;
    P)
        if [[ $OPTARG != "" ]]; then
            remote_ssh_port=$OPTARG
        fi
        ;;
    S)
        if [[ $OPTARG != "" ]]; then
            server_ip_override=$OPTARG
        fi
        ;;
    b)
        if [[ $OPTARG != "" ]]; then
            branch_hash=$OPTARG
        fi
        ;;
    c)
        if [[ $OPTARG != "" ]]; then
            cluster_id=$OPTARG
        fi
        ;;
    d)
        env_debug=1
        ;;
    f)
        if [[ $OPTARG != "" ]]; then
            test_filter=$OPTARG
        fi
        ;;
    g)
        if [[ $OPTARG != "" ]]; then
            test_group=$OPTARG
        fi
        ;;
    *)
        usage
        ;;
    esac
done

# Skip to the first non-option parameter.
shift $((OPTIND - 1))

if [[ -z "$1" || -z "$2" ]]; then
    usage
fi
client_name="$1"
shift
server_name="$1"
shift

if [[ -z $PODMAN ]]; then
    error "PODMAN must be set"
fi
debug "PODMAN is '$PODMAN'"

function get_container_ip() {
    local name desc
    name="$1"
    desc="$2"
    if [[ -z $name || -z $desc ]]; then
        error "Function usage: ${FUNCNAME[0]} CONTAINER_NAME DESCRIPTION"
    fi
    info "Fetching IP for $desc container '$name'"
    $PODMAN inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$name"
}

function get_container_hostname() {
    local name desc
    name="$1"
    desc="$2"
    if [[ -z $name || -z $desc ]]; then
        error "Function usage: ${FUNCNAME[0]} CONTAINER_NAME DESCRIPTION"
    fi
    info "Fetching hostname for $desc container '$name'"
    $PODMAN inspect -f '{{.Config.Hostname}}' "$name"
}

if [[ $client_ip_override != NONE ]]; then
    client_ip=$client_ip_override
else
    client_ip="$(get_container_ip "$client_name" client)"
fi
if [[ $server_ip_override != NONE ]]; then
    server_ip=$server_ip_override
else
    server_ip="$(get_container_ip "$server_name" server)"
fi
client_hostname="$(get_container_hostname "$client_name" client)"
server_hostname="$(get_container_hostname "$server_name" server)"

# Dump all config to stdout.
cat <<EOF
BRANCH_HASH=$branch_hash
CLUSTER_ID=$cluster_id
CLIENT_NAME=$client_name
CLIENT_HOSTNAME=$client_hostname
CLIENT_IP4=$client_ip
REMOTE_SSH_PORT=$remote_ssh_port
SERVER_NAME=$server_name
SERVER_HOSTNAME=$server_hostname
SERVER_IP4=$server_ip
TEST_FILTER=$test_filter
TEST_GROUP=$test_group
ENV_DEBUG=$env_debug
EOF
