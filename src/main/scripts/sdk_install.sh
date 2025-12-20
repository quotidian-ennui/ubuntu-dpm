#!/usr/bin/env bash
set -eo pipefail

BASEDIR=$(dirname "$0")
#shellcheck disable=SC1091
source "$BASEDIR/common.sh"
ACTION_LIST="tvm|"

source_actions() {
  for f in "$BASEDIR"/includes/sdk_install_*; do
    #shellcheck disable=SC1090
    source "$f"
    name=$(basename "$f")
    ACTION_LIST+="${name#sdk_install_}|"
  done
  ACTION_LIST=${ACTION_LIST%?}
}
_init_dirs
source_actions
ACTION=$1 || true
ACTION=${ACTION:="help"}
if [[ "$#" -ne "0" ]]; then shift; fi

if [[ ! "${ACTION}" =~ ^$ACTION_LIST$ ]]; then
  echo "Invalid action [$ACTION]"
  sdk_install_help
fi

sdk_install_tvm() {
  echo "⚠️ you probably want to use 'just sdk tenv' instead"
  sdk_install_tenv
}

"sdk_install_${ACTION}" "$@"
