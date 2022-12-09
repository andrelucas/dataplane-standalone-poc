## Makefile installed in /tools/Makefile in the running container.

# This is used as a control point for clients running the tests.

test:
	./test.sh

##
## Build tools.
##

# build-configure is for every image, ideally this should change very rarely.
build-configure:
	build/build-configure.sh

# stage-configure performs actions on the binaries that are uploaded, so must
# run after the staging directory is created.
staging-configure:
	build/staging-configure.sh

##
## Container configuration tools.
##

# post gets run when the container is actually running, so we have systemd and
# any other runtime tools available.
post: config-local config-module config-tls config-resolver config-ssh

config-local:
	@ldconfig
	@runtime/whoami.sh

config-module:
	@modprobe target_core_user

# This has to run in the container, not the build image.
config-tls:
	@runtime/create_ssl_creds.sh

config-client: config-common

config-server: config-common

config-common: config-resolver

config-resolver:
	@runtime/config-resolver.sh

config-ssh:
	@runtime/config-ssh.sh
