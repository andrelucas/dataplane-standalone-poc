#!/bin/bash

# Configure ssh so we can jump from client to server without interaction.

# shellcheck source=config.env.sample
source /dpll/config.env || exit 1
test "$ENV_DEBUG" = "1" && set -x
set -e

function info() {
	msg="$*"
	echo "-- $msg"
}

function debug() {
	if [[ $ENV_DEBUG = 1 ]]; then
		local msg="$*"
		echo "++ $msg" >&2
	fi
}

## The rest is ripped straight from rhel8-dpll:script/install and minimally
## changed to fit the container environment.

# Install ssh key.
debug "Installing local ssh key"
ikey=id_rsa_storageos_insecure_vagrant

# mkdir -p ~/.ssh
# chmod 0700 ~/.ssh
# cat $ikey.pub >>~/.ssh/authorized_keys
# cp $ikey ~/.ssh/$ikey
# chmod 600 ~/.ssh/$ikey

# cat <<EOF >~/.ssh/config
# Host *.local
# 	IdentityFile ~/.ssh/$ikey
# 	ControlMaster auto
# 	ControlPath ~/.ssh/%r@%h:%p
# EOF
# chmod 0600 ~/.ssh/config

mkdir -p ~root/.ssh
chmod 0700 ~root/.ssh
cp $ikey.pub ~root/.ssh/authorized_keys
cp $ikey ~root/.ssh/$ikey
chmod 600 ~root/.ssh/$ikey

# Ingenious use of tee(1) so we can use a heredoc with sudo:
#   http://stackoverflow.com/questions/4412029/generate-script-in-bash-and-save-it-to-location-requiring-sudo
tee ~root/.ssh/config >/dev/null <<EOF
Host client server
	IdentityFile ~/.ssh/$ikey
	ControlMaster auto
	ControlPath ~/.ssh/%r@%h:%p
EOF
chmod 0600 ~root/.ssh/config

# Turn off StrictHostKeyChecking. This will automatically add the remote host key to
# ~/.ssh/known_hosts
debug "Making ssh less secure but easier to script"
sconf=/etc/ssh/ssh_config
cp $sconf ${sconf}.bak
sed -e '/^# StorageOS BEGIN/,/^# StorageOS END/ d' ${sconf}.bak | sudo cp /dev/fd/0 ${sconf}
tee -a $sconf >/dev/null <<EOF
# StorageOS BEGIN

Host *
	StrictHostKeyChecking no

# StorageOS END
EOF
unset sconf
chmod 0644 /etc/ssh/ssh_config

exit 0
