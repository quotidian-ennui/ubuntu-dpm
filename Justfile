set positional-arguments := true
OS_NAME:=`uname -o | tr '[:upper:]' '[:lower:]'`

TOOL_CONFIG:=env_var_or_default("DPM_TOOLS_YAML", justfile_directory() / "config/tools.yml")

UPDATECLI_TEMPLATE:=justfile_directory() / "config/updatecli.yml"
LOCAL_CONFIG:= env_var('HOME') / ".config/ubuntu-dpm"
LOCAL_BIN:= env_var('HOME') / ".local/bin"
LOCAL_SHARE:= env_var('HOME') / ".local/share/ubuntu-dpm"
INSTALLED_VERSIONS:= LOCAL_CONFIG / "installed-versions"

alias prepare:=init

# show recipes
[private]
@help:
  just --list --list-prefix "  "
  echo ""
  echo "Generally, you'll just use 'just tools' to update the binary tools"

# run updatecli with args e.g. just updatecli diff
updatecli +args='diff':
  #!/usr/bin/env bash
  set -eo pipefail

  JQ_FILTER='
    {
      "repo": .repo,
      "yamlpath": .updatecli.yamlpath,
      "pattern": (if .updatecli.pattern == null then "*" else .updatecli.pattern end),
      "kind": (if .updatecli.kind == null then "semver" else .updatecli.kind end),
      "trim_prefix": .updatecli.trim_prefix
    }
    | with_entries(if .value == null then empty else . end)
  '
  tmpdir=$(mktemp -d -t updatecli.XXXXXX)
  # shellcheck disable=SC2002
  cat "{{ TOOL_CONFIG }}" | yq -p yaml -o json | jq -c ".[]" | while read -r line; do
    values=$(mktemp --tmpdir="$tmpdir" updatecli-values.XXXXXX.yml)
    hasRepo=$(echo "$line" | jq -r ".repo")
    if [[ "$hasRepo" != "null" ]]; then
      echo "$line" | jq "$JQ_FILTER" | yq -P -o yaml > "$values"
      GITHUB_TOKEN=$(gh auth token) updatecli "$@" --values "$values" -c "{{ UPDATECLI_TEMPLATE }}"
    fi
  done
  GITHUB_TOKEN=$(gh auth token) updatecli "$@"
  rm -rf "$tmpdir"

# Update apt + tools
update: apt_update tools
  #!/usr/bin/env bash

  set -eo pipefail
  # update fzf-git if we need to
  if [[ -d "{{ LOCAL_SHARE }}/fzf-git.sh" ]]; then
    echo ">>> updating fzf-git"
    cd "{{ LOCAL_SHARE }}/fzf-git.sh" && git pull --rebase
  fi

# initialise to install tools
init: is_supported configure_ghcli
  #!/usr/bin/env bash

  set -eo pipefail
  mkdir -p ~/.config/direnv && wget -q -O ~/.config/direnv/direnvrc https://raw.githubusercontent.com/direnv/direnv/master/stdlib.sh
  mkdir -p ~/.local/share/direnv/allow

# install binary tools
@tools: is_supported install_tools

# Show help for sdk subcommand
[private]
[no-exit-message]
[no-cd]
sdk_install_help:
  #!/usr/bin/env bash

  set -eo pipefail
  JUSTFILE_JSON=$(just --dump-format json --dump --unstable)
  tasks=$(echo "$JUSTFILE_JSON" | jq -c '.recipes | .[] | select( .name | test("^sdk_install_.*")) | { "recipe" : .name, "doc": .doc }')
  echo "just sdk <action>"
  while IFS= read -r line; do
    recipe=$(echo "$line" | jq -r '.recipe')
    doc=$(echo "$line" | jq -r '.doc')
    echo "  ${recipe/sdk_install_/}|$doc"
  done <<< "$tasks" | column -s"|" -t

# install your preferred set of SDKs
@sdk action='help' *args="": is_supported
  just sdk_install_{{action}} {{args}}

# Install all the SDK tooling
[private]
sdk_install_all: sdk_install_go sdk_install_rust sdk_install_nvm sdk_install_java (sdk_install_tvm "terraform") (sdk_install_tvm "opentofu") (sdk_install_aws "update")

# not entirely sure I like this as a chicken & egg situation since goenv must be installed
# by 'tools' recipe
# Install goenv (because golang)
[private]
sdk_install_go:
  #!/usr/bin/env bash

  set -eo pipefail
  go_v=$(goenv --list-remote | grep -v -e "beta" -e "rc[0-9]*" | sort -rV | head -n 1)
  goenv --install "$go_v"
  goenv --use "$go_v"

# Install SDKMAN (because JVM)
[private]
sdk_install_java:
  #!/usr/bin/env bash
  set -eo pipefail

  if [[ ! -d "$HOME/.sdkman" ]]; then
    # It does feel that if we already have SDKMAN installed then
    # we could execute sdk selfupdate & sdk upgrade
    curl -fSsL "https://get.sdkman.io" | bash
  fi
  # This is a bit of a hack to avoid the interactive prompt but setting
  # it on the commandline doesn't always work.
  sed -e "s|sdkman_auto_answer=false|sdkman_auto_answer=true|g" -i ~/.sdkman/etc/config
  #shellcheck disable=SC1090
  source ~/.sdkman/bin/sdkman-init.sh
  # graal_latest=$(gh release list -R graalvm/graalvm-ce-builds --json "tagName,isPrerelease,isLatest" -q '.[] | select (.isPrerelease == false) |  select (.isLatest == true) | .tagName')
  # JDK21 is LTS... so we'll use that
  graal_latest=jdk-21.0.2
  gradle_latest=$(gh release list -R gradle/gradle --json "tagName,isPrerelease,isLatest" -q '.[] | select (.isPrerelease == false) |  select (.isLatest == true) | .tagName')
  maven_latest=$(gh release list -R apache/maven --json "tagName,isPrerelease,isLatest" -q '.[] | select (.isPrerelease == false) |  select (.isLatest == true) | .tagName')
  jbang_latest=$(gh release list -R jbangdev/jbang --json "tagName,isPrerelease,isLatest" -q '.[] | select (.isPrerelease == false) |  select (.isLatest == true) | .tagName')

  graal_v=${graal_latest#"jdk-"}
  mvn_v=${maven_latest#"maven-"}
  gradle_v=${gradle_latest#"v"}
  # Need to use 8.5 rather than 8.5.0
  gradle_v=${gradle_v%".0"}
  jbang_v=${jbang_latest#"v"}

  sdk install java "$graal_v-graalce"
  sdk install gradle "$gradle_v"
  sdk install maven "$mvn_v"
  sdk install jbang "$jbang_v"
  echo "[+] GraalVM=$graal_v, Gradle=$gradle_v, Maven=$mvn_v, jbang=$jbang_v"
  sed -e "s|sdkman_auto_answer=true|sdkman_auto_answer=false|g" -i ~/.sdkman/etc/config

# Install NVM (because nodejs)
[private]
sdk_install_nvm:
  #!/usr/bin/env bash
  set -eo pipefail

  nvm_v=$(gh release list -R nvm-sh/nvm --json "tagName,isPrerelease,isLatest" -q '.[] | select (.isPrerelease == false) |  select (.isLatest == true) | .tagName')
  curl -fSsL "https://raw.githubusercontent.com/nvm-sh/nvm/$nvm_v/install.sh" | bash
  #shellcheck disable=SC1090
  source ~/.nvm/nvm.sh
  nvm install --lts && nvm use --lts
  npm install -g -y wsl-open pin-github-action prettier


# Install rustup && cargo-binstall (because rust)
[private]
sdk_install_rust:
  #!/usr/bin/env bash
  set -eo pipefail
  curl -fSsL --proto '=https' --tlsv1.2 https://sh.rustup.rs | sh -s -- -y --no-modify-path
  curl -fSsL "https://github.com/cargo-bins/cargo-binstall/releases/latest/download/cargo-binstall-x86_64-unknown-linux-musl.tgz" | tar xz
  ./cargo-binstall -y --force cargo-binstall >/dev/null 2>&1
  rm -f ./cargo-binstall >/dev/null 2>&1

# Install RVM (because ruby)
[private]
sdk_install_rvm:
  #!/usr/bin/env bash
  set -eo pipefail

  gpg --keyserver keyserver.ubuntu.com --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
  curl -fSsL "https://get.rvm.io" | bash -s stable
  #shellcheck disable=SC1090
  source ~/.rvm/scripts/rvm
  ruby_latest=$(gh release list -R ruby/ruby | grep -i Latest | awk '{print $1}')
  ruby_v=${ruby_latest#"v"}
  echo "Ruby $ruby_v" && rvm install ruby "$ruby_v" && rvm use "$ruby_v"

# Install one of the terraform env managers ($1=terraform/opentofu)
[private]
sdk_install_tvm variant:
  #!/usr/bin/env bash
  set -eo pipefail

  tfenv_base=""
  tfenv_github=""
  tfenv_yamlpath=""
  tfenv_bin=""
  #shellcheck disable=SC2194
  case "{{ variant }}" in
    terraform|tf)
      tfenv_base=".tfenv"
      tfenv_github="https://github.com/tfutils/tfenv"
      tfenv_yamlpath=".terraform.version"
      tfenv_bin="tfenv"
      ;;
    opentofu|tofu)
      tfenv_base=".tofuenv"
      tfenv_github="https://github.com/tofuutils/tofuenv"
      tfenv_yamlpath=".opentofu.version"
      tfenv_bin="tofuenv"
      ;;
    *) echo "Unknown variant: {{ variant }}"; exit 1 ;;
  esac
  if [[ -d "$HOME/$tfenv_base" ]]; then
    echo "{{ variant }} env manager already installed"
    (cd "$HOME/$tfenv_base" && git pull --rebase)
  else
    mkdir -p "{{ LOCAL_BIN }}"
    (cd "$HOME" && git clone "$tfenv_github" "$tfenv_base")
    #shellcheck disable=SC1083
    ln -s "$HOME/$tfenv_base/bin"/* {{ LOCAL_BIN }}
    #shellcheck disable=SC2002
    tf_v=$(cat "{{ TOOL_CONFIG }}" | yq -r "$tfenv_yamlpath")
    "$HOME/$tfenv_base/bin/$tfenv_bin" install "$tf_v"
    "$HOME/$tfenv_base/bin/$tfenv_bin" use "$tf_v"
  fi

# Install aws-cli ($1=update/install/uninstall)
[private]
sdk_install_aws action="update":
  #!/usr/bin/env bash
  set -eo pipefail

  download_and_run_installer() {
    tmpdir=$(mktemp -d -t awscli.XXXXXX)
    curl -fSsL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "$tmpdir/awscliv2.zip"
    unzip -q -d "$tmpdir" "$tmpdir/awscliv2.zip"
    (cd "$tmpdir" && sudo ./aws/install "$@")
    rm -rf "$tmpdir"
  }

  # since action is a just param
  # shellcheck disable=SC2194
  case "{{ action }}" in
    install)
      download_and_run_installer
      aws --version
      ;;
    uninstall|rm)
      sudo rm /usr/local/bin/aws
      sudo rm /usr/local/bin/aws_completer
      sudo rm -rf /usr/local/aws-cli
      echo "Skip deleting ~/.aws (chicken mode)"
      ;;
    update|upgrade)
      download_and_run_installer --update
      aws --version
      ;;
    *)
      echo "Installs / updates the AWS CLI"
      echo "just aws install|rm|update"
      exit 0
      ;;
  esac

[private]
install_tools:
  #!/usr/bin/env bash
  # Pre-Reqs:
  #  sudo apt install jq pipx
  #  pipx install gh-release-install (https://github.com/jooola/gh-release-install)
  # We're using SNAP which might require systemd
  # In /etc/wsl.conf in the linux distro
  # [boot]
  # systemd=true
  # and then do the wsl --shutdown restart dance.
  set -eo pipefail

  yq_wrapper() {
    if ! which yq >/dev/null 2>&1; then
      gh-release-install "mikefarah/yq" "yq_linux_amd64" "$HOME/.local/bin/yq" --version v4.43.1
      "$HOME/.local/bin/yq" "$@"
    else
      yq "$@"
    fi
  }

  write_installed() {
    {
      for i in "${!installed[@]}"; do
        echo "$i=${installed[$i]}"
      done
    } > "{{ INSTALLED_VERSIONS}}"
  }

  read_installed() {
    if [[ -f "{{ INSTALLED_VERSIONS}}" ]]; then
      # shellcheck disable=SC1097
      while IFS== read -r key value; do
        installed[$key]=$value
      done < "{{ INSTALLED_VERSIONS}}"
    fi
  }

  mkdir -p "{{ LOCAL_CONFIG }}"
  mkdir -p "{{ LOCAL_BIN }}"

  declare -A installed
  read_installed
  snap_apt=""
  # shellcheck disable=SC2002
  tools=$(cat "{{ TOOL_CONFIG }}" | yq_wrapper -p yaml -o json | jq -c ".[]")
  for line in $tools
  do
    repo=$(echo "$line" | jq -r ".repo")
    version=$(echo "$line" | jq -r ".version")
    artifact=$(echo "$line" | jq -r ".artifact")
    contents_line=$(echo "$line" | jq -r ".contents")
    extract=$(echo "$contents_line" | cut -f1 -d':')
    binary=$(echo "$contents_line" | cut -f2 -d':')
    binary=${binary:-$extract}
    if [[ -n "$extract" ]]; then
      extract_cmdline="--extract $extract"
    else
      extract_cmdline=""
    fi
    if [[ "$repo" != "null" ]]
    then
      if [[ "${installed[$binary]}" != "$version" || ! -x "{{ LOCAL_BIN }}/$binary" ]]
      then
        echo "[+] $binary@$version from $repo (attempt install)"
        # since extract_cmdline needs to be expanded.
        # shellcheck disable=SC2086
        gh-release-install "$repo" "$artifact" "{{ LOCAL_BIN }}/$binary" --version "$version" $extract_cmdline
        installed[$binary]="$version"
        case "$binary" in
          just | yq) snap_apt="true";;
          *) ;;
        esac
      else
        echo "[=] $binary@$version from $repo (already installed)"
        continue
      fi
    fi
  done
  write_installed
  # Cleanup Just (mpr has it at 1.14)
  if [[ -n "$snap_apt" ]]; then
    sudo apt remove -y just 1>/dev/null 2>&1 || true
    echo ">>> casey/just installed at $(which just)"
    echo ">>> mikefarah/yq installed at $(which yq)"
    echo "You might want to 'hash -r' to clear the bash hash cache."
  fi

[private]
configure_ghcli:
  #!/usr/bin/env bash
  set -eo pipefail

  if [[ -z "$DPM_SKIP_GHCLI_CONFIG" ]]; then
    if ! gh auth status >/dev/null 2>&1; then
      gh auth login -h github.com
    fi
    gh extension install quotidian-ennui/gh-my || true
    gh extension install quotidian-ennui/gh-rate-limit || true
    gh extension install quotidian-ennui/gh-squash-merge || true
    gh extension install quotidian-ennui/gh-approve-deploy || true
    gh extension install actions/gh-actions-cache || true
    gh extension install mcwarman/gh-update-pr || true
  fi

[private]
@apt_update:
  sudo apt -y update
  sudo apt -y upgrade

[private]
[no-cd]
[no-exit-message]
is_supported:
  #!/usr/bin/env bash
  set -eo pipefail

  # since OS_NAME is a just variable
  # shellcheck disable=SC2050
  if [[ "{{ OS_NAME }}" == "msys" ]]; then echo "Try again on WSL2+Ubuntu"; exit 1; fi
  if [[ -e "/etc/os-release" ]]; then
    # shellcheck disable=SC1091
    release=$(. /etc/os-release && echo "$ID" | tr '[:upper:]' '[:lower:]')
  else
    release=$(lsb_release -si | tr '[:upper:]' '[:lower:]') || true
  fi
  case "$release" in
    ubuntu|debian) ;;
    *) echo "Try again on Ubuntu or Debian"; exit 1;;
  esac


# install & use fzf-git with fzf
fzf-git:
  #!/usr/bin/env bash
  set -eo pipefail

  SUMMARY=""
  # install fzf-tmux since it's not in the fzf tar.gz
  if [[ ! -f "{{ LOCAL_BIN }}/fzf-tmux" ]]; then
    curl -fSsL https://raw.githubusercontent.com/junegunn/fzf/master/bin/fzf-tmux -o "{{ LOCAL_BIN }}/fzf-tmux"
    chmod +x "{{ LOCAL_BIN }}/fzf-tmux"
  fi
  mkdir -p "{{ LOCAL_SHARE }}"
  if [[ ! -d "{{ LOCAL_SHARE }}/fzf-git.sh" ]]; then
    cd "{{ LOCAL_SHARE }}" && git clone https://github.com/junegunn/fzf-git.sh
  else
    cd "{{ LOCAL_SHARE }}/fzf-git.sh" && git pull --rebase
  fi

  if [[ -z "$DPM_SKIP_FZF_PROFILE" ]]; then
    if ! grep "fzf --bash" "$HOME/.bashrc" >/dev/null 2>&1; then
      #shellcheck disable=SC2016
      printf '\n[[ -s "$HOME/.local/bin/fzf" ]] && eval $($HOME/.local/bin/fzf --bash)\n' >> "$HOME/.bashrc"
      SUMMARY+="\n>>> Added fzf --bash to .bashrc"
    fi
    if ! grep "fzf-git" "$HOME/.bashrc" >/dev/null 2>&1; then
      #shellcheck disable=SC2016
      printf '\n[[ -s "$HOME/.local/share/ubuntu-dpm/fzf-git.sh/fzf-git.sh" ]] && source "$HOME/.local/share/ubuntu-dpm/fzf-git.sh/fzf-git.sh"\n' >> "$HOME/.bashrc"
      SUMMARY+="\n>>> Added fzf-git.sh to .bashrc"
    fi
  fi
  echo -e "$SUMMARY"
