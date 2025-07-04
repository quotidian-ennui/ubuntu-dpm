set positional-arguments := true
set unstable := true
set script-interpreter := ['/usr/bin/env', 'bash']

TOOL_CONFIG:=env_var_or_default("DPM_TOOLS_YAML", justfile_directory() / "config/tools.yml")
REPO_CONFIG:=env_var_or_default("DPM_REPOS_YAML", justfile_directory() / "config/repos.yml")
SDK_CONFIG:=env_var_or_default("DPM_SDK_YAML", justfile_directory() / "config/sdk.yml")
ARCHIVE_CONFIG:=env_var_or_default("DPM_ARCHIVES_YAML", justfile_directory() / "config/archives.yml")
LOCAL_UPDATECLI:=justfile_directory() / "src/main/resources/local-updatecli.yml"
LOCAL_UPDATECLI_ARCHIVE:=justfile_directory() / "src/main/resources/local-archive-updatecli.yml"
SCRIPTS_DIR:=justfile_directory() / "src/main/scripts"
alias prepare:=init

# show recipes
[private]
@help:
  just --list --list-prefix "  "
  echo ""
  echo "Generally, you'll just use 'just tools' to update the binary tools"

# run updatecli with args e.g. just updatecli diff
[script]
updatecli type='personal' +args='diff':
  # comment to avoid syntax-highlight issues
  case "{{ type }}" in
  additions | local | personal)
    UPDATE_TYPE="{{ type }}" UPDATECLI_ARCHIVE_TEMPLATE="{{ LOCAL_UPDATECLI_ARCHIVE }}" UPDATECLI_TEMPLATE="{{ LOCAL_UPDATECLI }}" ARCHIVE_CONFIG="$DPM_ARCHIVES_ADDITIONS_YAML" TOOL_CONFIG="$DPM_TOOLS_ADDITIONS_YAML" "{{ SCRIPTS_DIR }}/updatecli.sh" {{ args }}
    ;;
  *)
    TOOL_CONFIG="{{ TOOL_CONFIG }}" ARCHIVE_CONFIG="{{ ARCHIVE_CONFIG }}" "{{ SCRIPTS_DIR }}/updatecli.sh" {{ args }}
    ;;
  esac

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
  sudo apt -y autoremove

[private]
[no-cd]
[no-exit-message]
@is_supported:
  ARCHIVE_CONFIG="{{ ARCHIVE_CONFIG }}" TOOL_CONFIG="{{ TOOL_CONFIG }}" REPO_CONFIG="{{ REPO_CONFIG }}" SDK_CONFIG="{{ SDK_CONFIG }}" "{{ SCRIPTS_DIR }}/is_supported.sh"

# use fzf-git with fzf
@fzf-git:
  ARCHIVE_CONFIG="{{ ARCHIVE_CONFIG }}" TOOL_CONFIG="{{ TOOL_CONFIG }}" REPO_CONFIG="{{ REPO_CONFIG }}" SDK_CONFIG="{{ SDK_CONFIG }}" "{{ SCRIPTS_DIR }}/fzf-git.sh"
