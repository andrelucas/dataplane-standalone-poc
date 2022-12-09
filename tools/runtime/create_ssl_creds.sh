#!/bin/bash

# Use this on a running node, where `hostname` is a useful commant. It's not
# like a normal CA situation, as we have all the CA keying information locally
# as it's baked into the build image. We can just generate a signed cert
# locally.
#
# Note that $CERTNAME is found in /dpll/config.env, placed there by whoami.sh.
# That's the CN we'll get and the tls override will have to match it.

# shellcheck source=../config.env.sample
source /dpll/config.env || exit 1
test "$ENV_DEBUG" = "1" && set -x
set -e

function info() {
    local msg="$*"
    echo "-- $msg" >&2
}

function debug() {
    if [[ $ENV_DEBUG = 1 ]]; then
        local msg="$*"
        echo "++ $msg" >&2
    fi
}

CA_CERT=/dpll/ca.crt
CA_KEY=/dpll/ca.key

OUTPUT_DIR=/dpll

# Create client cert-key pair
NODE_CERT=$OUTPUT_DIR/node.crt
NODE_KEY=$OUTPUT_DIR/node.key
debug "Creating node RSA key"
/usr/bin/openssl genrsa -out $NODE_KEY 2048 >/dev/null 2>&1
debug "Creating node TLS certificate request"
/usr/bin/openssl req -new -sha256 -key $NODE_KEY -subj "/C=GB/ST=London/O=dpll-node-$(hostname)/CN=$CERTNAME" -out node.csr >/dev/null 2>&1
debug "Creating node TLS certificate"
/usr/bin/openssl x509 -req -in node.csr -CA $CA_CERT -CAkey $CA_KEY -CAcreateserial -out $NODE_CERT -days 500 -sha256 >/dev/null 2>&1
#/usr/bin/openssl x509 -in $NODE_CERT -text -noout

rm node.csr

exit 0
