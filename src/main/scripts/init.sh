#!/usr/bin/env bash
set -eo pipefail

BASEDIR=$(dirname "$0")
source "$BASEDIR/common.sh"
ACTION_LIST=()

source_actions() {
  for f in "$BASEDIR"/includes/init_*; do
    #shellcheck disable=SC1090
    source "$f"
    name=$(basename "$f")
    ACTION_LIST+=("${name}")
  done
}

source_actions
for action in $ACTION_LIST; do
  "${action}"
done
