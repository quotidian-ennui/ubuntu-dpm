#!/usr/bin/env bash
# shellcheck disable=SC2002
source "$(dirname "$0")/common.sh"

set -eo pipefail
go_v=$(cat "$SDK_CONFIG" | yq -r ".golang.version")
# go_v=$(goenv --list-remote | grep -v -e "beta" -e "rc[0-9]*" | sort -rV | head -n 1)
goenv --install "$go_v"
goenv --use "$go_v"
