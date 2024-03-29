set positional-arguments := true
OS_NAME:=`uname -o | tr '[:upper:]' '[:lower:]'`
TOOL_CONFIG:=justfile_directory() / "config/tools.yml"
UPDATECLI_TEMPLATE:=justfile_directory() / "config/updatecli.yml"
LOCAL_CONFIG:= env_var('HOME') / ".config/ubuntu-dpm"
LOCAL_BIN:= env_var('HOME') / ".local/bin"
INSTALLED_VERSIONS:= LOCAL_CONFIG / "installed-versions"
SKIP_DOCKER:= env_var_or_default("SKIP_DOCKER", "")
CURL:="curl -fSsL"

alias install:=tools
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
@update: apt_update tools

# initialise to install tools
init: is_supported configure_ghcli
  #!/usr/bin/env bash

  set -eo pipefail
  mkdir -p ~/.config/direnv && wget -q -O ~/.config/direnv/direnvrc https://raw.githubusercontent.com/direnv/direnv/master/stdlib.sh
  mkdir -p ~/.local/share/direnv/allow

# install binary tools
@tools: is_supported install_tools

# install all the sdk tooling
@sdk: is_supported install_sdkman install_nvm install_rvm install_rust install_go (install_tvm "terraform") (install_tvm "opentofu")

# not entirely sure I like this as a chicken & egg situation since goenv must be installed
# by 'tools' recipe
# Install goenv (because golang)
install_go:
  #!/usr/bin/env bash

  set -eo pipefail
  go_v=$(goenv --list-remote | grep -v -e "beta" -e "rc[0-9]*" | sort -rV | head -n 1)
  goenv --install "$go_v"
  goenv --use "$go_v"

# Install SDKMAN (because JVM)
install_sdkman:
  #!/usr/bin/env bash
  set -eo pipefail

  if [[ ! -d "$HOME/.sdkman" ]]; then
    # It does feel that if we already have SDKMAN installed then
    # we could execute sdk selfupdate & sdk upgrade
    {{ CURL }} "https://get.sdkman.io" | bash
  fi
  # This is a bit of a hack to avoid the interactive prompt but setting
  # it on the commandline doesn't always work.
  sed -e "s|sdkman_auto_answer=false|sdkman_auto_answer=true|g" -i ~/.sdkman/etc/config
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
install_nvm:
  #!/usr/bin/env bash
  set -eo pipefail

  nvm_v=$(gh release list -R nvm-sh/nvm --json "tagName,isPrerelease,isLatest" -q '.[] | select (.isPrerelease == false) |  select (.isLatest == true) | .tagName')
  {{ CURL }}  "https://raw.githubusercontent.com/nvm-sh/nvm/$nvm_v/install.sh" | bash
  source ~/.nvm/nvm.sh
  nvm install --lts && nvm use --lts

# Install rustup && cargo-binstall (because rust)
install_rust:
  #!/usr/bin/env bash
  set -eo pipefail
  {{ CURL }}  --proto '=https' --tlsv1.2 https://sh.rustup.rs | sh -s -- -y
  {{ CURL }} "https://github.com/cargo-bins/cargo-binstall/releases/latest/download/cargo-binstall-x86_64-unknown-linux-musl.tgz" | tar xz
  ./cargo-binstall -y --force cargo-binstall >/dev/null 2>&1
  rm -f ./cargo-binstall >/dev/null 2>&1

# Install RVM (because ruby)
install_rvm:
  #!/usr/bin/env bash
  set -eo pipefail

  gpg --keyserver keyserver.ubuntu.com --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
  {{ CURL }}  "https://get.rvm.io" | bash -s stable
  source ~/.rvm/scripts/rvm
  ruby_latest=$(gh release list -R ruby/ruby | grep -i Latest | awk '{print $1}')
  ruby_v=${ruby_latest#"v"}
  echo "Ruby $ruby_v" && rvm install ruby "$ruby_v" && rvm use "$ruby_v"

# Install one of the terraform env managers (terraform|opentofu)
install_tvm variant:
  #!/usr/bin/env bash
  set -eo pipefail

  tfenv_base=""
  tfenv_github=""
  tfenv_yamlpath=""
  tfenv_bin=""
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
    (cd $HOME && git clone "$tfenv_github" "$tfenv_base")
    ln -s $HOME/$tfenv_base/bin/* {{ LOCAL_BIN }}
    tf_v=$(cat "{{ TOOL_CONFIG }}" | yq -r "$tfenv_yamlpath")
    $HOME/$tfenv_base/bin/$tfenv_bin install "$tf_v"
    $HOME/$tfenv_base/bin/$tfenv_bin use "$tf_v"
  fi

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

  yq_init() {
    if ! which yq >/dev/null 2>&1; then
      docker pull mikefarah/yq
    fi
  }

  yq_wrapper() {
    if ! which yq >/dev/null 2>&1; then
      docker run --rm -i -v "${PWD}":/workdir mikefarah/yq "$@"
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
      while IFS== read -r key value; do
        installed[$key]=$value
      done < "{{ INSTALLED_VERSIONS}}"
    fi
  }

  mkdir -p "{{ LOCAL_CONFIG }}"
  mkdir -p "{{ LOCAL_BIN }}"
  yq_init

  declare -A installed
  read_installed
  snap_apt=""
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

  if ! gh auth status >/dev/null 2>&1; then
    gh auth login -h github.com
  fi
  gh extension install quotidian-ennui/gh-my || true
  gh extension install quotidian-ennui/gh-rate-limit || true
  gh extension install quotidian-ennui/gh-squash-merge || true
  gh extension install quotidian-ennui/gh-approve-deploy || true
  gh extension install actions/gh-actions-cache || true
  gh extension install mcwarman/gh-update-pr || true

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

  if [[ "{{ OS_NAME }}" == "msys" ]]; then echo "Try again on WSL2+Ubuntu"; exit 1; fi
  if [[ -e "/etc/os-release" ]]; then
    release=$(. /etc/os-release && echo "$ID" | tr '[:upper:]' '[:lower:]')
  else
    release=$(lsb_release -si | tr '[:upper:]' '[:lower:]') || true
  fi
  case "$release" in
    ubuntu|debian) ;;
    *) echo "Try again on Ubuntu or Debian"; exit 1;;
  esac
