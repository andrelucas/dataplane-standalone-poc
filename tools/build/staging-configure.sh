#!/bin/bash

# Build-time configuration.
#
# Configuration that can only be performed once the binaries and tests have
# been copied into the image.

test "$BUILD_DEBUG" = "1" && set -x
set -e

function do_ldconfig() {
    echo -e "${DP_DESTDIR}/lib\n${DP_DESTDIR}/lib64" >/etc/ld.so.conf.d/dpll.conf
    chmod 0644 /etc/ld.so.conf.d/dpll.conf
    ldconfig
}

do_ldconfig

exit 0
