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

#############################################################################

# Standalone PoC support.

CONSUMER_COUNT				?= $(shell date '+%s')
DEPLOYMENT_UUID				?= NOTSET
PRESENTATION_FILENAME		?= my_volume
PRESENTATION_UUID			?= badc0ffe-e0dd-f00d-0000-000000000001
REMOTE_NODE_IP				?= NOTSET
REMOTE_NODE_UUID			?= NOTSET
SIZE_BYTES					?= NOTSET

poc-connect:
	env HOSTNAME_OVERRIDE=client \
		/staging/bin/supctl \
			ConfigurePresentation \
			--config.deployment_uuid $(DEPLOYMENT_UUID) \
			--config.presentation_uuid $(PRESENTATION_UUID) \
			--config.cc.consumer_count $(CONSUMER_COUNT) \
			--config.filename $(PRESENTATION_FILENAME) \
			--config.size $(SIZE_BYTES) \
			--config.opt_node_config.uuid $(REMOTE_NODE_UUID) \
			--config.opt_node_config.hostname $(REMOTE_NODE_IP) \
			--config.opt_node_config.port 5703 \
			--config.opt_node_config.tls_enabled true \
			--config.opt_node_config.opt_verify_hostname storageos:node:$(REMOTE_NODE_UUID)

# This target is an easy way to check if we've configured everything
# properly, so we can connect to the local data plane's supervisor module.
# It'll return '{}' with one (unimportant) warning message.
#
poc-checksup:
	env HOSTNAME_OVERRIDE=client \
		/staging/bin/supctl Status
