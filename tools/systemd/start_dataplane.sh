#!/bin/bash

# If present /tmp/director_env.conf provides the environment to use when starting director.
# This environment should be placed in director_env.conf as a single space seperated list of variables
# stored within the var DIRECTOR_ENV. For example:
#      DIRECTOR_ENV="DIRECTOR_ERROR_GENERATOR_ENABLED=1 RDB_ERROR_GENERATOR_ENABLED=1".
# If /tmp/director_env.conf is not present we'll use the default below.

# Note: if DIRECTOR_ERROR_GENERATOR_ENABLED is set to 1 we'll generate a NON_FATAL error
# for every read and write IO that hits director.
# If RDB_ERROR_GENERATOR_ENABLED is set we'll generate an error for every read and write
# IO that hits rdbplugin. The type of error which is generated is based on the integer
# argument that RDB_ERROR_GENERATOR_ENABLED is set to. These integers map onto the error
# enums definied in io_result.hpp. For example, 32768 (1<<15) is an IOError::FATAL.
DIRECTOR_ENV="DIRECTOR_ERROR_GENERATOR_ENABLED=1 RDB_ERROR_GENERATOR_ENABLED=32768"
if [ -f /tmp/director_env.conf ]; then
    # shellcheck disable=SC1091
    source /tmp/director_env.conf
    echo "Using environment from /tmp/director_env.conf to start director: ${DIRECTOR_ENV}"
else
    echo "Using default environment to start director: ${DIRECTOR_ENV}"
fi
# Parse a space-separated list of environment variables into an array, so we can
# safely hand it to the dataplane later.
declare -a dir_env
for e in $DIRECTOR_ENV; do
    dir_env+=("$e")
done

# Check default UNIX domain socket directory exists
if [ ! -d /run/storageos ]; then
    mkdir -p /run/storageos
fi

# extra_env is a Bash array. This means we can potentially have items with
# spaces in and get predictable-ish results.
declare -a extra_env
if [ -z "$LOG_LEVEL" ] && [ -z "$LOG_FILTER" ]; then
    extra_env+=("LOG_LEVEL=xdebug")
fi

# The DPLL tests use TLS secured connections for inter-node communication. We must therefore
# set the appropriate TLS env vars. To start the dataplane without TLS in directfs set DISABLE_TLS=1.
# Note: this cause the DPLL tests to fail so should only be used for local hacking.
if [[ ! -f $CA_CERT_PATH ]] || [[ ! -f $NODE_CERT_PATH ]] || [[ ! -f $NODE_PRIVATE_KEY_PATH ]]; then
    echo "CA_CERT_PATH, NODE_CERT_PATH and NODE_PRIVATE_KEY_PATH must all be set and valid"
    exit 1
fi

extra_env+=("CA_CERT_PATH=$CA_CERT_PATH")
extra_env+=("NODE_CERT_PATH=$NODE_CERT_PATH")
extra_env+=("NODE_PRIVATE_KEY_PATH=$NODE_PRIVATE_KEY_PATH")

dbdir=/tmp/test
mkdir -p "$dbdir"
exec env "${dir_env[@]}" "${extra_env[@]}" /st/dataplane --dir "$dbdir"
