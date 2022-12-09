#!/bin/bash

# Runtime configuration (in container).

# Configure dns etc. so we can address test hosts by name. Have a section at
# the end of /etc/hosts between some markers that points at our nodes.

# shellcheck source=config.env.sample
source /dpll/config.env || exit 1
test "$ENV_DEBUG" = "1" && set -x
set -e

m_begin="# BEGIN dpll"
m_end="# END dpll"

tempdir="$(mktemp -d -t resolver.XXXXX)"
trap 'rm -rf "$tempdir"' exit

tempfile="$tempdir/hosts"

# Write a hosts file without the marked section.
sed -e "/^$m_begin/,/^$m_end/ d" /etc/hosts >"$tempfile"
# Add the marked section with our values.
cat <<EOF >>"$tempfile"
$m_begin
$CLIENT_IP4 client $CLIENT_NAME
$SERVER_IP4 server $SERVER_NAME
$m_end
EOF

cp "$tempfile" /etc/hosts
exit 0
