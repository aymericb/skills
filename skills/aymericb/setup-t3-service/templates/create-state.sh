#!/bin/sh

set -eu

state_dir="${1:-.state}"

mkdir -p \
    "$state_dir/t3"

printf 'Created Dev Container state directories in %s\n' "$state_dir"
