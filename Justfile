set positional-arguments := true

TOOL_CONFIG:=env_var_or_default("DPM_TOOLS_YAML", justfile_directory() / "config/tools.yml")
REPO_CONFIG:=env_var_or_default("DPM_REPOS_YAML", justfile_directory() / "config/repos.yml")
SDK_CONFIG:=env_var_or_default("DPM_SDK_YAML", justfile_directory() / "config/sdk.yml")
SCRIPTS_DIR:=justfile_directory() / "src/main/scripts"

alias prepare:=init

# show recipes
[private]
@help:
  just --list --list-prefix "  "
  echo ""
  echo "Generally, you'll just use 'just tools' to update the binary tools"

# run updatecli with args e.g. just updatecli diff
@updatecli +args='diff':
  TOOL_CONFIG="{{ TOOL_CONFIG }}" REPO_CONFIG="{{ REPO_CONFIG }}" SDK_CONFIG="{{ SDK_CONFIG }}" "{{ SCRIPTS_DIR }}/updatecli.sh" "$@"

# Update apt + tools
@update: apt_update tools

# initialise to install tools
@init: is_supported
  TOOL_CONFIG="{{ TOOL_CONFIG }}" REPO_CONFIG="{{ REPO_CONFIG }}" SDK_CONFIG="{{ SDK_CONFIG }}" "{{ SCRIPTS_DIR }}/init.sh"

# install binary tools and checkout repo scripts
@tools: is_supported install_tools install_repos

# Show help for sdk subcommand
[private]
[no-exit-message]
[no-cd]
@sdk_install_help:
  "{{ SCRIPTS_DIR }}/just_help.sh" "sdk" "sdk_install_"

# install your preferred set of SDKs
@sdk *args="help": is_supported
  TOOL_CONFIG="{{ TOOL_CONFIG }}" REPO_CONFIG="{{ REPO_CONFIG }}" SDK_CONFIG="{{ SDK_CONFIG }}"  "{{ SCRIPTS_DIR }}/sdk_install.sh" "$@"

[private]
@install_tools:
  TOOL_CONFIG="{{ TOOL_CONFIG }}" REPO_CONFIG="{{ REPO_CONFIG }}" SDK_CONFIG="{{ SDK_CONFIG }}" TOOL_CONFIG="{{ TOOL_CONFIG }}" "{{ SCRIPTS_DIR }}/install_tools.sh"

[private]
@install_repos:
  TOOL_CONFIG="{{ TOOL_CONFIG }}" REPO_CONFIG="{{ REPO_CONFIG }}" SDK_CONFIG="{{ SDK_CONFIG }}" "{{ SCRIPTS_DIR }}/install_repos.sh"

# configure github cli & extensions
@ghcli:
  TOOL_CONFIG="{{ TOOL_CONFIG }}" REPO_CONFIG="{{ REPO_CONFIG }}" SDK_CONFIG="{{ SDK_CONFIG }}"  "{{ SCRIPTS_DIR }}/configure_ghcli.sh"

[private]
@apt_update:
  sudo apt -y update
  sudo apt -y upgrade

[private]
[no-cd]
[no-exit-message]
@is_supported:
  TOOL_CONFIG="{{ TOOL_CONFIG }}" REPO_CONFIG="{{ REPO_CONFIG }}" SDK_CONFIG="{{ SDK_CONFIG }}" "{{ SCRIPTS_DIR }}/is_supported.sh"

# use fzf-git with fzf
@fzf-git:
  TOOL_CONFIG="{{ TOOL_CONFIG }}" REPO_CONFIG="{{ REPO_CONFIG }}" SDK_CONFIG="{{ SDK_CONFIG }}" "{{ SCRIPTS_DIR }}/fzf-git.sh"
