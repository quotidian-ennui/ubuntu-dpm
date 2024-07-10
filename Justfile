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
  TOOL_CONFIG="{{ TOOL_CONFIG }}" REPO_CONFIG="{{ REPO_CONFIG }}" SDK_CONFIG="{{ SDK_CONFIG }}" "{{ SCRIPTS_DIR }}/init_direnv.sh"

# install binary tools and checkout repo scripts
@tools: is_supported install_tools install_repos

# Show help for sdk subcommand
[private]
[no-exit-message]
[no-cd]
@sdk_install_help:
  "{{ SCRIPTS_DIR }}/just_help.sh" "sdk" "sdk_install_"

# install your preferred set of SDKs
@sdk action='help' *args="": is_supported
  just sdk_install_{{action}} {{args}}

# Install rust, nvm, sdkman, tofu, aws (but not go).
[private]
sdk_install_all: sdk_install_rust sdk_install_nvm sdk_install_java (sdk_install_tvm "opentofu") (sdk_install_aws "update")

# not entirely sure I like this as a chicken & egg situation since goenv must be installed
# by 'tools' recipe
# Install ankitcharolia/goenv to manage golang
[private]
sdk_install_go:
  TOOL_CONFIG="{{ TOOL_CONFIG }}" REPO_CONFIG="{{ REPO_CONFIG }}" SDK_CONFIG="{{ SDK_CONFIG }}"  "{{ SCRIPTS_DIR }}/sdk_install_go.sh"

# Install/Update go-nv/goenv to manage golang ($1=install/update)
[private]
@sdk_install_goenv action="update":
  TOOL_CONFIG="{{ TOOL_CONFIG }}" REPO_CONFIG="{{ REPO_CONFIG }}" SDK_CONFIG="{{ SDK_CONFIG }}" "{{ SCRIPTS_DIR }}/sdk_install_goenv.sh" "$@"

# Install SDKMAN (because JVM)
[private]
@sdk_install_java:
  TOOL_CONFIG="{{ TOOL_CONFIG }}" REPO_CONFIG="{{ REPO_CONFIG }}" SDK_CONFIG="{{ SDK_CONFIG }}" "{{ SCRIPTS_DIR }}/sdk_install_java.sh"

# Install NVM (because nodejs)
[private]
@sdk_install_nvm:
  TOOL_CONFIG="{{ TOOL_CONFIG }}" REPO_CONFIG="{{ REPO_CONFIG }}" SDK_CONFIG="{{ SDK_CONFIG }}" "{{ SCRIPTS_DIR }}/sdk_install_nvm.sh"

# Install rustup && cargo-binstall (because rust)
[private]
@sdk_install_rust:
  TOOL_CONFIG="{{ TOOL_CONFIG }}" REPO_CONFIG="{{ REPO_CONFIG }}" SDK_CONFIG="{{ SDK_CONFIG }}" "{{ SCRIPTS_DIR }}/sdk_install_rust.sh"

# Install RVM (because ruby)
[private]
sdk_install_rvm:
  TOOL_CONFIG="{{ TOOL_CONFIG }}" REPO_CONFIG="{{ REPO_CONFIG }}" SDK_CONFIG="{{ SDK_CONFIG }}" "{{ SCRIPTS_DIR }}/sdk_install_rvm.sh"

# Install one of the terraform env managers ($1=terraform/opentofu)
[private]
@sdk_install_tvm variant:
  TOOL_CONFIG="{{ TOOL_CONFIG }}" REPO_CONFIG="{{ REPO_CONFIG }}" SDK_CONFIG="{{ SDK_CONFIG }}" "{{ SCRIPTS_DIR }}/sdk_install_tvm.sh" "$@"

# Install aws-cli ($1=update/install/uninstall)
[private]
@sdk_install_aws action="update":
  TOOL_CONFIG="{{ TOOL_CONFIG }}" REPO_CONFIG="{{ REPO_CONFIG }}" SDK_CONFIG="{{ SDK_CONFIG }}" "{{ SCRIPTS_DIR }}/sdk_install_aws.sh" "$@"

# Install sonar-scanner cli
[private]
@sdk_install_sonar-scanner:
  TOOL_CONFIG="{{ TOOL_CONFIG }}" REPO_CONFIG="{{ REPO_CONFIG }}" SDK_CONFIG="{{ SDK_CONFIG }}" "{{ SCRIPTS_DIR }}/sdk_install_sonar_scanner.sh" "$@"

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
