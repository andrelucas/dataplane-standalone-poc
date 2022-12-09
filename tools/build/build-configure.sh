#!/bin/bash

# Build-time configuration: Configure the dpll runtime image.
#
# Make sure to COPY this script into the image, so changes to the script cause
# the image to be rebuilt. However, run this as late as you can in the build,
# so a tiny script change doesn't cause mass rebuilding.

test "$BUILD_DEBUG" = "1" && set -x
set -e

function do_layout() {
    # This is required to run.
    mkdir -p /run/storageos
    # This is for per-node runtime files etc.
    mkdir -p /dpll
    local d
    for d in artifacts crash data volumes; do
        mkdir -p /var/lib/storageos/$d
    done
    ## Convenience symlinks.
    # Symlink /vsl -> /var/lib/storageos
    rm -f /vls
    ln -s /var/lib/storageos /vls
    # Symlink /v -> /var/lib/storageos/volumes
    rm -f /v
    ln -s /var/lib/storageos/volumes /v
    # Symlink /staging/libexec/inttest -> /test
    rm -f /test
    ln -s /staging/libexec/inttest /test
}

function do_vagrant_paths() {
    # Emulate the vagrant file layout so vagrant-based dpll still works. This
    # is straightforward - both /vagrant/install and /staging are just the
    # contents of dataplane's 'make install'. Also, rhel8-dpll's
    # script/start_dataplane.sh uses shortcut path /st/ for /va. Sigh.

    mkdir -p /vagrant
    # Symlink /vagrant/install -> /staging
    rm -f /vagrant/install
    ln -s /staging /vagrant/install
    # Symlink /st -> /staging/sbin
    rm -f /st
    ln -s /staging/sbin /st
}

function do_systemd() {
    local unitfile
    unitfile=/etc/systemd/system/s-dataplane.service
    rm -f $unitfile
    ln -s /tools/systemd/s-dataplane.service $unitfile
    # Don't run daemon-reload here, we're in 'podman build' and systemd isn't
    # running.

    # This file has to exist or the service won't start.
    touch /etc/sysconfig/dataplane

}

function do_env() {
    # Set this environment variable for all(ish) shells.
    cat <<EOF >/etc/profile.d/dpll.sh
# Turn off testing anonymous namespace feature.
DO_NOT_RUN_TESTS_IN_ANON_NETWORK_NAMESPACE=1
export DO_NOT_RUN_TESTS_IN_ANON_NETWORK_NAMESPACE

# Set the standard cert paths.
CA_CERT_PATH=/dpll/ca.crt
NODE_CERT_PATH=/dpll/node.crt
NODE_PRIVATE_KEY_PATH=/dpll/node.key
export CA_CERT_PATH NODE_CERT_PATH NODE_PRIVATE_KEY_PATH
EOF
    chmod 0644 /etc/profile.d/dpll.sh
}

function do_sshd() {
    cat <<EOF >>/etc/ssh/sshd_config
# Begin Ondat options.
UseDNS no
GSSAPIAuthentication no
# END Ondat options.
EOF
}

do_layout
do_vagrant_paths
do_sshd
do_systemd
do_env

exit 0
