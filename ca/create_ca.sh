#!/bin/bash

# This is the CA shared by all nodes, and has to run at image build time so
# all nodes agree on what the CA is.

test "$BUILD_DEBUG" = "1" && set -x
set -e

scriptdir="$(dirname $0)"

OUTPUT_DIR="$scriptdir"
CA_KEY=$OUTPUT_DIR/ca.key
CA_CRT=$OUTPUT_DIR/ca.crt

# Create root key
echo "Creating CA RSA key"
/usr/bin/openssl genrsa -out "$CA_KEY" 4096

# Create and self sign the Root Certificate
/usr/bin/openssl req -x509 -new -nodes -key "$CA_KEY" -sha256 -days 999999 -out "$CA_CRT" -subj "/C=GB/ST=London/O=dpll-ca/CN=dpll-ca.com"
