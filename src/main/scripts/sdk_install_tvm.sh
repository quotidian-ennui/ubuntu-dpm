#!/usr/bin/env bash
set -eo pipefail

source "$(dirname "$0")/common.sh"

tfenv_base=""
tfenv_github=""
tfenv_yamlpath=""
tfenv_bin=""
case "$1" in
terraform | tf)
  tfenv_base=".tfenv"
  tfenv_github="https://github.com/tfutils/tfenv"
  tfenv_yamlpath=".terraform.version"
  tfenv_bin="tfenv"
  ;;
opentofu | tofu)
  tfenv_base=".tofuenv"
  tfenv_github="https://github.com/tofuutils/tofuenv"
  tfenv_yamlpath=".opentofu.version"
  tfenv_bin="tofuenv"
  ;;
*)
  echo "Unknown variant: $1"
  exit 1
  ;;
esac
if [[ -d "$HOME/$tfenv_base" ]]; then
  echo "$1 env manager already installed"
  (cd "$HOME/$tfenv_base" && git pull --rebase)
else
  mkdir -p "$LOCAL_BIN"
  (cd "$HOME" && git clone "$tfenv_github" "$tfenv_base")
  #shellcheck disable=SC1083
  ln -s "$HOME/$tfenv_base/bin"/* "$LOCAL_BIN"
  #shellcheck disable=SC2002
  tf_v=$(cat "$SDK_CONFIG" | yq -r "$tfenv_yamlpath")
  "$HOME/$tfenv_base/bin/$tfenv_bin" install "$tf_v"
  "$HOME/$tfenv_base/bin/$tfenv_bin" use "$tf_v"
fi
