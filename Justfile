set positional-arguments := true
OS_NAME:=`uname -o | tr '[:upper:]' '[:lower:]'`
VERSION_FILE:=justfile_directory() / "config/versions.yml"
TOOL_CONFIG:=justfile_directory() / "config/tools.yml"

# show recipes
[private]
@help:
  just --list --list-prefix "  "

# run updatecli with args e.g. just updatecli diff
updatecli +args='diff':
  #!/usr/bin/env bash
  GITHUB_TOKEN=$(gh auth token) updatecli --values "{{ VERSION_FILE }}" "$@"

# initialise to install tools
@init: is_ubuntu install_base install_github_cli install_tfenv

# install tooling
@install: is_ubuntu install_tools

[private]
install_tools:
  #!/usr/bin/env bash
  # Pre-Reqs:
  #  sudo apt install jq python3-pip
  #  pip install gh-release-install (https://github.com/jooola/gh-release-install)
  #  pip install yq
  #
  set -euo pipefail

  tf_v=$(cat "{{ VERSION_FILE }}" | yq -r ".versions.terraform")
  tfenv install "$tf_v"
  tfenv use "$tf_v"

  cat "{{ TOOL_CONFIG }}" | yq -c ".[]" | while read line; do
    repo=$(echo "$line" | jq -r ".repo")
    version=$(echo "$line" | jq -r ".version")
    artifact=$(echo "$line" | jq -r ".artifact")
    extract=$(echo "$line" | jq -r ".extract")
    binary=$(echo "$line" | jq -r ".binary")
    if [[ "$extract" != "null" ]]; then
      extract_cmdline="--extract $extract"
    else
      extract_cmdline=""
    fi
    gh-release-install "$repo" "$artifact" "$HOME/.local/bin/$binary" --verbose --version "$version" $extract_cmdline
  done

[private]
install_github_cli:
  #!/usr/bin/env bash
  set -eo pipefail

  if ! gh auth status; then
    gh auth login -h github.com
  fi
  gh extension install quotidian-ennui/gh-my || true
  gh extension install quotidian-ennui/gh-rate-limit || true
  gh extension install quotidian-ennui/gh-squash-merge || true
  gh extension install quotidian-ennui/gh-approve-deploy || true
  gh extension install actions/gh-actions-cache || true
  gh extension install mcwarman/gh-update-pr || true

[private]
install_base:
  #!/usr/bin/env bash
  set -eo pipefail

  sudo apt-get -y install kubectl helm gh jq python3-pip
  if [[ -z "$WSL_DISTRO_NAME" ]]; then
    sudo apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  fi
  pip install gh-release-install yq

[private]
install_tfenv:
  #!/usr/bin/env bash
  set -eo pipefail

  if [[ -d "$HOME/.tfenv" ]]; then
    echo "tfenv already installed"
    (cd $HOME/.tfenv && git pull --rebase)
  else
    (cd $HOME && git clone https://github.com/tfutils/tfenv .tfenv)
    ln -s $HOME/.tfenv/bin/* $HOME/.local/bin
  fi

[private]
[no-cd]
[no-exit-message]
is_ubuntu:
  #!/usr/bin/env bash
  set -eo pipefail

  if [[ "{{ OS_NAME }}" == "msys" ]]; then echo "Try again on WSL2+Ubuntu"; exit 1; fi
  if [[ "$(lsb_release -si)" != "Ubuntu" ]]; then echo "Try again on Ubuntu"; exit 1; fi