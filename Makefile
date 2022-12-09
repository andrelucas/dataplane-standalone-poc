# test/Makefile
#
# Dataplane integration test.

#############################################################################

## Things that might usefully be configured.

TEST_GROUP			?= all
TEST_FILTER			?= *

# This is used to differentiate between multiple clusters on a single host.
CLUSTER_ID			?= local

# Set EXPOSE_CLIENT or EXPOSE_SERVER to publish a dataplane on its standard
# port. Don't expose both; that won't work.
EXPOSE_CLIENT		?= false
EXPOSE_SERVER		?= false

# This will get changed in EXPOSE_CLIENT or EXPOSE_SERVER mode.
REMOTE_SSH_PORT		= 22

# Set CLIENT_IP_OVERRIDE or SERVER_IP_OVERRIDE to, well, override the client
# or server IP address set in /etc/hosts on the containers. See the README.
CLIENT_IP_OVERRIDE	?=
SERVER_IP_OVERRIDE	?=

OUTPUT_DIR			?= $(CURDIR)/output

STRIP_TEST_BINARIES	?= true

# Passed to run/genconfig.sh to generate config sent to the containers.
#CONFIG_EXTRA		?= -d
CONFIG_EXTRA		?=

# If either of these are set to 1, enable extra debugging. BUILD_DEBUG is for
# the docker image build, and ENV_DEBUG is for runtime (the containers).
BUILD_DEBUG			?=
ENV_DEBUG			?=

#############################################################################

## Things you probably shouldn't be configuring unless you're working on the
## tools themselves.

BRANCH_HASH			= $(shell git rev-parse --abbrev-ref HEAD | sha256sum | cut -c1-12)
HOST_PREFIX			= $(BRANCH_HASH)-$(CLUSTER_ID)

CLIENT_NAME			= $(HOST_PREFIX)-c1
CLIENT_SSH_FWD_PORT	=
SERVER_NAME			= $(HOST_PREFIX)-c2
SERVER_SSH_FWD_PORT	=

DEPS_TARBALL_PREFIX	?=	Bundle

ARCH				?= $(shell uname -m)
DIST				?= rhel-

DEPS_TARBALL	= $(DEPS_TARBALL_PREFIX)-$(ARCH).tar.gz

DPLL_IMAGE		= dpll
DPLL_TAG		= latest

STAGING_DIR			?= $(CURDIR)/staging
LOCKFILE			= dp.lock
LOCKDIR_HOST		?= $(PWD)/shared
LOCKDIR_CONTAINER	= /shared

CONTAINER_STAGING	= /staging
INTTEST_DIR			= $(CONTAINER_STAGING)/libexec/inttest

DPSRC			= $(CURDIR)/..
DPINSTALLDIR	= $(DPSRC)/install

SUDO			= sudo
PODMAN			= $(SUDO) podman

LABEL			= --label dpll

NODE_OPTIONS	+= -v /sys:/sys

NODE_OPTIONS	+= -v /dev:/dev
NODE_OPTIONS	+= -v $(LOCKDIR_HOST):$(LOCKDIR_CONTAINER)
NODE_OPTIONS	+= -v /lib/modules:/lib/modules
NODE_OPTIONS	+= -v $(STAGING_DIR):$(CONTAINER_STAGING)
NODE_OPTIONS	+= --privileged --cap-add=SYS_ADMIN

#NODE_EXTRA		= -v $(PWD)/..:/src

CLIENT_OPTIONS	?=
SERVER_OPTIONS	?=

DEFAULT_EXPOSED_SSH_PORT	?= 2022

# Selectively expose key ports.
ifeq ($(strip $(EXPOSE_CLIENT)),true)
REMOTE_SSH_PORT	= $(DEFAULT_EXPOSED_SSH_PORT)
CLIENT_OPTIONS	+= -p 5703:5703 -p 5704:5704 -p $(REMOTE_SSH_PORT):22
endif
ifeq ($(strip $(EXPOSE_SERVER)),true)
REMOTE_SSH_PORT	= $(DEFAULT_EXPOSED_SSH_PORT)
SERVER_OPTIONS	+= -p 5703:5703 -p 5704:5704 -p $(REMOTE_SSH_PORT):22
endif

CA_CRT			= ca/ca.crt
CA_KEY			= ca/ca.key

#############################################################################

## Local CA support. The CA is created once, and copied into the container at
## runtime.

.PHONY: ca
ca: $(CA_CRT) $(CA_KEY)
$(CA_CRT) $(CA_KEY):
	ca/create_ca.sh

cleanca:
	rm -f $(CA_CRT) $(CA_KEY)

#############################################################################

## Test image build and container run.

.PHONY: build
build: ca Dockerfile
	$(PODMAN) build -t $(DPLL_IMAGE):$(DPLL_TAG) .

.PHONY: start
start:
	mkdir -p $(OUTPUT_DIR)
	$(PODMAN) rm -f $(CLIENT_NAME) $(SERVER_NAME)
	$(SUDO) mkdir -p $(LOCKDIR_HOST)
	$(SUDO) touch $(LOCKDIR_HOST)/$(LOCKFILE)
	$(PODMAN) run --name $(CLIENT_NAME) -d $(CLIENT_OPTIONS) -p $(CLIENT_SSH_FWD_PORT):22 $(LABEL) $(NODE_OPTIONS) $(NODE_EXTRA) $(DPLL_IMAGE):$(DPLL_TAG)
	$(PODMAN) run --name $(SERVER_NAME) -d $(SERVER_OPTIONS) -p $(SERVER_SSH_FWD_PORT):22 $(LABEL) $(NODE_OPTIONS) $(NODE_EXTRA) $(DPLL_IMAGE):$(DPLL_TAG)

CONFIG_FILE		= run/config.env
# This can be just 'make', as WORKDIR is /tools.
CONFMAKE		= make

# config puts genconfig's output on the containers, then configures the
# containers using that config.
.PHONY: config
config: genconfig
	@echo "-- Uploading runtime configuration"
	@for h in $(CLIENT_NAME) $(SERVER_NAME); do \
		for c in $(CONFIG_FILE) $(CA_CRT) $(CA_KEY); do \
			$(PODMAN) cp $$c $$h:/dpll/; \
		done; \
		$(PODMAN) exec $$h /bin/bash -c '$(CONFMAKE) post'; \
	done
	@echo "-- Using CLUSTER_ID=$(CLUSTER_ID)"

# genconfig runs on the host, and extracts configuration from podman.
.PHONY: genconfig cleanconfig reconfig
genconfig: $(CONFIG_FILE)
cleanconfig:
	rm -f $(CONFIG_FILE)

# reconfig forces a new configuration upload.
reconfig: cleanconfig config


$(CONFIG_FILE): run/genconfig.sh
	@echo "-- Generating runtime configuration"
	@rm -f $@
	env PODMAN="$(PODMAN)" run/genconfig.sh \
		-b "$(BRANCH_HASH)" -c "$(CLUSTER_ID)" -g "$(TEST_GROUP)" \
		-f "$(TEST_FILTER)" $(CONFIG_EXTRA) \
		-C "$(CLIENT_IP_OVERRIDE)" -S "$(SERVER_IP_OVERRIDE)" \
		-P "$(REMOTE_SSH_PORT)" \
		$(CLIENT_NAME) $(SERVER_NAME) >$@

.PHONY: down up refresh

up: down build start cleanconfig config

down:
	$(PODMAN) kill --signal=KILL $(CLIENT_NAME) $(SERVER_NAME) || true

refresh: down stage up

.PHONY: check test
test: reconfig check
check:
	$(PODMAN) exec $(CLIENT_NAME) bash -c '$(CONFMAKE) test LOG_LEVEL=trace'

.PHONY: shell shellclient shellserver
shell: shellclient
shellclient:
	$(PODMAN) exec -ti $(CLIENT_NAME) /bin/bash
shellserver:
	$(PODMAN) exec -ti $(SERVER_NAME) /bin/bash


###
###

#############################################################################

# Artifact injection. When the containers are run, staging/ needs to have the
# same file layout as 'make install' in the source tree.

download:
	@echo "Not yet supported" >&2
	@exit 1

# Stage-src does largely the same thing as the Artifactory download, but for
# locally-generated source. That is, assuming `make install` has installed to
# <data>/install, copy everything from there to staging/.
#
stage:
	@# rsync(1) is very sensitive to the trailing slash, be careful.
	rsync -a --delete --partial $(DPINSTALLDIR)/* $(STAGING_DIR)/

STAGING_TARBALL	= $(CURDIR)/staging.tgz

stage-to-tarball: stage
	cd $(STAGING_DIR) && tar czf $(STAGING_TARBALL) *

stage-from-tarball: stage
	rm -r $(STAGING_DIR)/*
	tar -C $(STAGING_DIR) -xzf $(STAGING_TARBALL)

strip:
	test "$(STRIP_TEST_BINARIES)" = true && \
		find $(STAGING_DIR)/libexec/inttest -type f -a -name "test_*" | xargs strip && \
		find $(STAGING_DIR)/bin -type f | xargs strip && \
		find $(STAGING_DIR)/sbin -type f -a -not -name "dataplane" | xargs strip

