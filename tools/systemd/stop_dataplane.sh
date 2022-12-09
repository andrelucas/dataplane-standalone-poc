#!/bin/bash

## Synchronous director stop script.

# Give systemd a way to shut down the dataplane that really makes sure it's
# down.
#
# If systemd has a working ExecStop= script, we can use `systemctl restart`
# safely, because restart is stop-then-start, and we can be sure that stop
# completes before returning to systemd.

set -e -u
# set -x

# The dataplane daemon process.
pname="dataplane"

# Message displayed for logs.
function info() {
    if [ ! -t 1 ]; then
        echo "$*"
    fi
}

# Message displayed interactively.
function status() {
    if [ -t 1 ]; then
        echo -n "$*"
    fi
}

function warn() {
    echo "WARN: $*" >&2
}

function error() {
    echo "ERROR: $*" >&2
    exit 1
}

function funcusage() {
    echo "Function: ${FUNCNAME[1]} $*" >&2
    exit 1
}

function find_by_name() {
    # Don't exit if this fails, just return nothing.
    pgrep -u root "^$pname$" || true
}

function find_by_pid() {
    local pid
    if [ $# != 1 ] || [ -z "$1" ]; then
        funcusage "PID"
    fi
    pid="$1"
    # shellcheck disable=SC2009
    if ps -eo pid | grep -q "^ *$pid$"; then
        echo "$pid"
    fi
}

function stop_by_pid() {
    local pid
    if [ $# != 2 ] || [ -z "$1" ] || [ -z "$2" ]; then
        funcusage "PID SIGNAL"
    fi
    pid="$1"
    sig="$2"
    # Display the first character of the signal name.
    status "${sig:0:1}"
    # If this fails, it might mean the process stopped in between testing
    # for its presence and the kill(1) command.
    kill -"$sig" "$pid" || true
}

pid="$(find_by_name)"

if [ -z "$pid" ]; then
    warn "Dataplane process '$pname' does not appear to be running"
    exit 0
fi

retries=500
waitsec=0.1
first=1

status "Stopping: "

for r in $(seq 1 $retries); do
    stop_by_pid "$pid" TERM
    info "Clean stop pid $pid attempt $r/$retries: Waiting ${waitsec}s"
    # Deal quickly with an immediate stop.
    if [ $first -eq 1 ]; then
        if [ -z "$(find_by_pid "$pid")" ]; then
            break
        fi
        first=0
    fi
    sleep $waitsec
    if [ -z "$(find_by_pid "$pid")" ]; then
        break
    fi
done

if [ -z "$(find_by_pid "$pid")" ]; then
    # Clean shutdown.
    echo
else
    stop_by_pid "$pid" KILL
    echo
    warn "Clean shutdown failed, sent SIGKILL"
fi

exit 0
