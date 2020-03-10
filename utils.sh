#!/usr/bin/env bash

set -euo pipefail

#=======================  F u n c t i o n s  =======================#

die() {
	printf '\033[1;31mERROR:\033[0m %s\n' "$@" >&2  # bold red
	exit 1
}

einfo() {
	printf '\n\033[1;36m> %s\033[0m\n' "$@" >&2  # bold cyan
}

ewarn() {
	printf '\033[1;33m> %s\033[0m\n' "$@" >&2  # bold yellow
}

usage() {
	sed -En '/^#---help---/,/^#---help---/p' "$0" | sed -E 's/^# ?//; 1d;$d;'
}

check_dep() {
    EXEC_CHECK=$1
    hash "$EXEC_CHECK" 2>/dev/null || { echo >&2 "$EXEC_CHECK is required but it's not installed. Aborting."; exit 1; }
}
