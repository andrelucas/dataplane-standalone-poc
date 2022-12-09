#!/bin/bash

# Runtime configuration: Determine which role this host performs.
#
# Write configuration files:
# - /dpll/config.env
# - /etc/profile.d/dpllnode.sh
# - /etc/sysconfig/dataplane

# shellcheck source=../config.env.sample
source /dpll/config.env || exit 1
test "$ENV_DEBUG" = "1" && set -x
set -e

function info() {
    msg="$*"
    echo "-- $msg" >&2
}

function debug() {
    if [[ $ENV_DEBUG = 1 ]]; then
        local msg="$*"
        echo "++ $msg" >&2
    fi
}

function error() {
    msg="$*"
    echo "ERROR: $msg" >&2
    exit 1
}

# Compare our hostname to those in config.env

hn="$(hostname)"

function uuid_from_id() {
    local id
    id="$1"
    if [[ ${#id} -ne 12 ]]; then
        error "${FUNCNAME[0]}: id '$id' must be 12 characters long"
    fi
    echo "00000000-0000-0000-0000-$id"
}

if [[ $hn = "$CLIENT_HOSTNAME" ]]; then
    info "$hn is the client"
    role=client
    certname=client
    nodeuuid="$(uuid_from_id $CLIENT_HOSTNAME)"
    peeruuid="$(uuid_from_id $SERVER_HOSTNAME)"

elif [[ $hn = "$SERVER_HOSTNAME" ]]; then
    info "$hn is the server"
    role=server
    certname=server
    nodeuuid="$(uuid_from_id $SERVER_HOSTNAME)"
    peeruuid="$(uuid_from_id $CLIENT_HOSTNAME)"

else
    error "Unable to determine role for container with hostname $hn"
fi

# The instance name is a combination of the branch hash, cluster id and the
# role in the cluster. That's what's needed to uniq the dataplane on a
# potentially shared host.
instance_name="${BRANCH_HASH}-${CLUSTER_ID}-${role}"
lockfile=/shared/dp.lock

# Update /dpll/config.env.
cat <<EOF >>/dpll/config.env
ROLE=$role
CERTNAME=$certname
NODE_UUID=$nodeuuid
PEER_UUID=$peeruuid
DATAPLANE_INSTANCE_NAME=$instance_name
DATAPLANE_IPC_LOCKFILE=$lockfile
EOF

# Set the UUID so it will be present for all shells.
# Set a variable that identities DPLL-in-Docker explicitly.
prof=/etc/profile.d/dpllnode.sh
cat <<EOF >$prof
DATAPLANE_BINARY_PATH=/staging/sbin/dataplane
DATAPLANE_INSTANCE_NAME=$instance_name
DATAPLANE_IPC_LOCKFILE=$lockfile
DIRECTFS_NODE_UUID=$nodeuuid
DIRECTFS_PEER_UUID=$peeruuid
DPLL_IN_DOCKER=1
DPLL_REMOTE_SSH_PORT=$REMOTE_SSH_PORT
export DATAPLANE_INSTANCE_NAME DATAPLANE_IPC_LOCKFILE
export DIRECTFS_NODE_UUID DIRECTFS_PEER_UUID
export DPLL_IN_DOCKER DPLL_REMOTE_SSH_PORT
EOF
chmod 0644 $prof

# Write the systemd configuration file too.
sysconf=/etc/sysconfig/dataplane
cat <<EOF >$sysconf
DATAPLANE_BINARY_PATH=/staging/sbin/dataplane
DATAPLANE_INSTANCE_NAME=$instance_name
DATAPLANE_IPC_LOCKFILE=$lockfile
DIRECTFS_NODE_UUID=$nodeuuid
DIRECTFS_PEER_UUID=$peeruuid
DO_NOT_RUN_TESTS_IN_ANON_NETWORK_NAMESPACE=1
DPLL_REMOTE_SSH_PORT=$REMOTE_SSH_PORT
EOF

exit 0
