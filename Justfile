set positional-arguments := true

TOOL_CONFIG:=env_var_or_default("DPM_TOOLS_YAML", justfile_directory() / "config/tools.yml")
REPO_CONFIG:=env_var_or_default("DPM_REPOS_YAML", justfile_directory() / "config/repos.yml")
SDK_CONFIG:=env_var_or_default("DPM_SDK_YAML", justfile_directory() / "config/sdk.yml")
ARCHIVE_CONFIG:=env_var_or_default("DPM_ARCHIVES_YAML", justfile_directory() / "config/archives.yml")
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
  ARCHIVE_CONFIG="{{ ARCHIVE_CONFIG }}" TOOL_CONFIG="{{ TOOL_CONFIG }}" REPO_CONFIG="{{ REPO_CONFIG }}" SDK_CONFIG="{{ SDK_CONFIG }}" "{{ SCRIPTS_DIR }}/updatecli.sh" "$@"

# Update apt + tools
@update: apt_update tools

# initialise to install tools
@init: is_supported
  ARCHIVE_CONFIG="{{ ARCHIVE_CONFIG }}" TOOL_CONFIG="{{ TOOL_CONFIG }}" REPO_CONFIG="{{ REPO_CONFIG }}" SDK_CONFIG="{{ SDK_CONFIG }}" "{{ SCRIPTS_DIR }}/init.sh"

# wrapper to install tools, repos
@tools: (install "tools") (install "repos")

# install binary tools/repos/apps
@install *args="help": is_supported
  ARCHIVE_CONFIG="{{ ARCHIVE_CONFIG }}" TOOL_CONFIG="{{ TOOL_CONFIG }}" REPO_CONFIG="{{ REPO_CONFIG }}" SDK_CONFIG="{{ SDK_CONFIG }}" "{{ SCRIPTS_DIR }}/install.sh" "$@"

# install your preferred set of SDKs
@sdk *args="help": is_supported
  ARCHIVE_CONFIG="{{ ARCHIVE_CONFIG }}" TOOL_CONFIG="{{ TOOL_CONFIG }}" REPO_CONFIG="{{ REPO_CONFIG }}" SDK_CONFIG="{{ SDK_CONFIG }}"  "{{ SCRIPTS_DIR }}/sdk_install.sh" "$@"

# configure github cli & extensions
@ghcli:
  ARCHIVE_CONFIG="{{ ARCHIVE_CONFIG }}" TOOL_CONFIG="{{ TOOL_CONFIG }}" REPO_CONFIG="{{ REPO_CONFIG }}" SDK_CONFIG="{{ SDK_CONFIG }}"  "{{ SCRIPTS_DIR }}/configure_ghcli.sh"

[private]
@apt_update:
  sudo apt -y update
  sudo apt -y upgrade

[private]
[no-cd]
[no-exit-message]
@is_supported:
  ARCHIVE_CONFIG="{{ ARCHIVE_CONFIG }}" TOOL_CONFIG="{{ TOOL_CONFIG }}" REPO_CONFIG="{{ REPO_CONFIG }}" SDK_CONFIG="{{ SDK_CONFIG }}" "{{ SCRIPTS_DIR }}/is_supported.sh"

# use fzf-git with fzf
@fzf-git:
  ARCHIVE_CONFIG="{{ ARCHIVE_CONFIG }}" TOOL_CONFIG="{{ TOOL_CONFIG }}" REPO_CONFIG="{{ REPO_CONFIG }}" SDK_CONFIG="{{ SDK_CONFIG }}" "{{ SCRIPTS_DIR }}/fzf-git.sh"
