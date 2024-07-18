#!/usr/bin/env bash
set -eo pipefail

BASEDIR=$(dirname "$0")
#shellcheck disable=SC1091
source "$BASEDIR/common.sh"
ACTION_LIST="all|"

source_actions() {
  for f in "$BASEDIR"/includes/install_*; do
    #shellcheck disable=SC1090
    source "$f"
    name=$(basename "$f")
    ACTION_LIST+="${name#install_}|"
  done
  ACTION_LIST=${ACTION_LIST%?}
}

write_installed() {
  {
    for i in "${!installed[@]}"; do
      echo "$i=${installed[$i]}"
    done
  } >"$INSTALLED_VERSIONS"
}

read_installed() {
  if [[ -f "$INSTALLED_VERSIONS" ]]; then
    # shellcheck disable=SC1097
    while IFS== read -r key value; do
      installed[$key]=$value
    done <"$INSTALLED_VERSIONS"
  fi
}

install_all() {
  install_tools
  install_repos
  install_archives
}

declare -A installed
_init_dirs
source_actions
ACTION=$1 || true
ACTION=${ACTION:="help"}
if [[ "$#" -ne "0" ]]; then shift; fi

if [[ ! "${ACTION}" =~ ^$ACTION_LIST$ ]]; then
  echo "Invalid action [$ACTION]"
  install_help
fi

read_installed
"install_${ACTION}" "$@"
write_installed
