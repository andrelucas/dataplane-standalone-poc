#!/bin/bash

# Check the dataplane has started by using the supervisor Status RPC
#
# TODO(AJReid): DP-521. Do this properly once we have a working supctl.
# For now just poll until the supervisor RPC port is up.

function error() {
	echo "ERROR:$*" >&2
	exit 1
}

function info() {
	echo "$*"
}

clidir=/testbin
prestart_delay_sec=0.1
retries=100
retry_delay_sec=0.1

#if [ ! -x supctl ]; then
#	error "'supctl' not executable"
#fi

info "Waiting ${prestart_delay_sec}s before startup check"
sleep $prestart_delay_sec

function module_check() {
	local cli="$1"
	shift
	local cmd="${clidir}/${cli} $*"
	$cmd status | grep -E 'state:' | grep -qE READY
}

success=0
for r in $(seq 1 $retries); do
	#if module_check supctl --srv-override $(hostname).local; then
	if nc -z 127.0.0.1 5703; then
		success=$r
		break
	fi
	info "Attempt $r/$retries failed, waiting ${retry_delay_sec}s"
	sleep $retry_delay_sec
done

if [ $success -eq 0 ]; then
	error "Failed to detect startup after $retries attempts"
fi

info "Started after $success attempts"
exit 0
