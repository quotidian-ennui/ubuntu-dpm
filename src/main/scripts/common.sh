#!/usr/bin/env bash

# shellcheck disable=SC2034
ROOT=$(git rev-parse --show-toplevel)

SDK_CONFIG=${SDK_CONFIG:-$ROOT/config/sdk.yml}
TOOL_CONFIG=${TOOL_CONFIG:-$ROOT/config/tools.yml}
REPO_CONFIG=${REPO_CONFIG:-$ROOT/config/repos.yml}
ARCHIVE_CONFIG=${APPDIR_CONFIG:-$ROOT/config/archives.yml}

LOCAL_CONFIG=${LOCAL_CONFIG:-$HOME/.config/ubuntu-dpm}
LOCAL_SHARE=${LOCAL_SHARE:-$HOME/.local/share/ubuntu-dpm}
LOCAL_BIN=${LOCAL_BIN:-$HOME/.local/bin}
INSTALLED_VERSIONS=${INSTALLED_VERSIONS:-$LOCAL_CONFIG/installed-versions}
UPDATECLI_TEMPLATE=${UPDATECLI_TEMPLATE:-$ROOT/config/updatecli.yml}
GOENV_ROOT=${GOENV_ROOT:-$HOME/.goenv}

_init_dirs() {
  mkdir -p "$LOCAL_SHARE"
  mkdir -p "$LOCAL_CONFIG"
  mkdir -p "$LOCAL_BIN"
}

yq_wrapper() {
  if ! which yq >/dev/null 2>&1; then
    gh-release-install "mikefarah/yq" "yq_linux_amd64" "$LOCAL_BIN/yq" --version v4.43.1
    "$LOCAL_BIN/yq" "$@"
  else
    yq "$@"
  fi
}
