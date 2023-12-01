set positional-arguments := true
OS_NAME:=`uname -o | tr '[:upper:]' '[:lower:]'`
TOOL_CONFIG:=justfile_directory() / "config/tools.yml"
UPDATECLI_TEMPLATE:=justfile_directory() / "config/updatecli.yml"

# show recipes
[private]
@help:
  just --list --list-prefix "  "

# run updatecli with args e.g. just updatecli diff
updatecli +args='diff':
  #!/usr/bin/env bash
  set -eo pipefail

  JQ_FILTER='
    { "repo": .repo,
      "yamlpath": .updatecli.yamlpath,
      "version_pinning": .updatecli.version_pinning,
      "trim_prefix": .updatecli.trim_prefix
    } | with_entries(if .value == null then empty else . end)
  '
  tmpdir=$(mktemp -d -t updatecli.XXXXXX)
  cat "{{ TOOL_CONFIG }}" | yq -c ".[]" | while read line; do
    values=$(mktemp --tmpdir="$tmpdir" updatecli-values.XXXXXX.yml)
    hasRepo=$(echo "$line" | jq -r ".repo")
    if [[ "$hasRepo" != "null" ]]; then
      echo $line | jq "$JQ_FILTER" | yq -y > "$values"
      GITHUB_TOKEN=$(gh auth token) updatecli "$@" --values "$values" -c "{{ UPDATECLI_TEMPLATE }}"
    fi
  done
  rm -rf "$tmpdir"

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

  tf_v=$(cat "{{ TOOL_CONFIG }}" | yq -r ".terraform.version")
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
    if [[ "$repo" != "null" ]]; then
      gh-release-install "$repo" "$artifact" "$HOME/.local/bin/$binary" --verbose --version "$version" $extract_cmdline
    fi
  done

[private]
updatecli_foreach:


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