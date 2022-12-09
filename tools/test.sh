#!/bin/bash

# Actually run some tests.

# Pull in configuration just in case we're noninteractive.
source /dpll/config.env || exit 1
source /etc/profile.d/dpll.sh || exit 1
source /etc/profile.d/dpllnode.sh || exit 1

test "$ENV_DEBUG" = "1" && set -x
set -e -u

# shellcheck source=config.env.sample
source /dpll/config.env

cd /staging/libexec/inttest

declare -a topt
if [[ $TEST_GROUP != NONE && $TEST_GROUP != all ]]; then
    # run-inttest.sh in group mode only takes one option, the group name.
    # Without an option, it runs everything.
    topt+=("$TEST_GROUP")
fi

# If TEST_FILTER is non-empty, append it.
if [[ -n $TEST_FILTER ]]; then
    topt+=("--gtest_filter=$TEST_FILTER")
fi

# This is the tool already installed by `make install`.
./run-inttest.sh "${topt[@]}"
