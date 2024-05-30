set positional-arguments := true
OS_NAME:=`uname -o | tr '[:upper:]' '[:lower:]'`

TOOL_CONFIG:=env_var_or_default("DPM_TOOLS_YAML", justfile_directory() / "config/tools.yml")
REPO_CONFIG:=env_var_or_default("DPM_REPOS_YAML", justfile_directory() / "config/repos.yml")
SDK_CONFIG:=env_var_or_default("DPM_SDK_YAML", justfile_directory() / "config/sdk.yml")

UPDATECLI_TEMPLATE:=justfile_directory() / "config/updatecli.yml"
LOCAL_CONFIG:= env_var('HOME') / ".config/ubuntu-dpm"
LOCAL_BIN:= env_var('HOME') / ".local/bin"
LOCAL_SHARE:= env_var('HOME') / ".local/share/ubuntu-dpm"
GOENV_ROOT:= env_var('HOME') / ".goenv"
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
      "repo": .value.repo,
      "yamlpath": (if .value.updatecli.yamlpath == null then "$.\(.key).version" else .value.updatecli.yamlpath end),
      "pattern": (if .value.updatecli.pattern == null then "*" else .value.updatecli.pattern end),
      "kind": (if .value.updatecli.kind == null then "semver" else .value.updatecli.kind end),
      "trim_prefix": .value.updatecli.trim_prefix
    }
    | with_entries(if .value == null then empty else . end)
  '
  tmpdir=$(mktemp -d -t updatecli.XXXXXX)
  # shellcheck disable=SC2002
  cat "{{ TOOL_CONFIG }}" | yq -p yaml -o json | jq -c "to_entries | .[]" | while read -r line; do
    values=$(mktemp --tmpdir="$tmpdir" updatecli-values.XXXXXX.yml)
    hasRepo=$(echo "$line" | jq -r ".value.repo")
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
init: is_supported
  #!/usr/bin/env bash

  set -eo pipefail
  mkdir -p ~/.config/direnv && wget -q -O ~/.config/direnv/direnvrc https://raw.githubusercontent.com/direnv/direnv/master/stdlib.sh
  mkdir -p ~/.local/share/direnv/allow

# install binary tools and checkout repo scripts
@tools: is_supported install_tools install_repos

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

# Install rust, nvm, sdkman, tofu, aws (but not go).
[private]
sdk_install_all: sdk_install_rust sdk_install_nvm sdk_install_java (sdk_install_tvm "opentofu") (sdk_install_aws "update")

# not entirely sure I like this as a chicken & egg situation since goenv must be installed
# by 'tools' recipe
# Install ankitcharolia/goenv to manage golang
[private]
sdk_install_go:
  #!/usr/bin/env bash
  # shellcheck disable=SC2002

  set -eo pipefail
  go_v=$(cat "{{ SDK_CONFIG }}" | yq -r ".golang.version")
  # go_v=$(goenv --list-remote | grep -v -e "beta" -e "rc[0-9]*" | sort -rV | head -n 1)
  goenv --install "$go_v"
  goenv --use "$go_v"


# Install/Update go-nv/goenv to manage golang ($1=install/update)
[private]
sdk_install_goenv action="update":
  #!/usr/bin/env bash
  # shellcheck disable=SC2016
  # shellcheck disable=SC2002

  set -eo pipefail
  mkdir -p "{{ LOCAL_BIN }}"

  rm -f "{{ LOCAL_BIN }}/goenv"
  if [[ -d "{{ GOENV_ROOT }}" ]]; then
    cd "{{ GOENV_ROOT }}" && git pull --rebase
  else
    git clone "https://github.com/go-nv/goenv.git" "{{ GOENV_ROOT }}"
  fi
  #shellcheck disable=SC1083
  ln -s "{{ GOENV_ROOT }}/bin/"* {{ LOCAL_BIN }}
  # shellcheck disable=SC2194
  case "{{ action }}" in
  install|latest)
    if [[ -z "$DPM_SKIP_GO_PROFILE" ]]; then
      if ! grep -q 'export GOENV_ROOT="$HOME/.goenv"' ~/.bashrc 2>/dev/null; then
        {
          printf '\nif [[ -d "$HOME/.goenv" ]]; then'
          printf '\n  export GOENV_ROOT="$HOME/.goenv"'
          printf '\n  eval "$($GOENV_ROOT/bin/goenv init -)"'
          printf '\nfi'
        } >> ~/.bashrc
      fi
    fi
    go_v=$(cat "{{ SDK_CONFIG }}" | yq -r ".golang.version")
    "{{ GOENV_ROOT }}/bin/goenv" install -s "$go_v"
    "{{ GOENV_ROOT }}/bin/goenv" global "$go_v"
    "{{ GOENV_ROOT }}/bin/goenv" versions
    ;;
  *)
    echo ">>> goenv updated"
    ;;
  esac

# Install SDKMAN (because JVM)
[private]
sdk_install_java:
  #!/usr/bin/env bash
  #Disable redundant cat throughout the scrsipt.
  #shellcheck disable=SC2002
  set -eo pipefail

  if [[ ! -d "$HOME/.sdkman" ]]; then
    # It does feel that if we already have SDKMAN installed then
    # we could execute sdk selfupdate & sdk upgrade
    if [[ -n "$DPM_SKIP_JAVA_PROFILE" ]]; then
      curl -fSsL "https://get.sdkman.io?rcupdate=false" | bash
    else
      curl -fSsL "https://get.sdkman.io" | bash
    fi
  fi
  # This is a bit of a hack to avoid the interactive prompt but setting
  # it on the commandline doesn't always work.
  sed -e "s|sdkman_auto_answer=false|sdkman_auto_answer=true|g" -i ~/.sdkman/etc/config
  #shellcheck disable=SC1090
  source ~/.sdkman/bin/sdkman-init.sh

  graal_v=$(cat "{{ SDK_CONFIG }}" | yq -r ".sdkman.java")
  maven_v=$(cat "{{ SDK_CONFIG }}" | yq -r ".sdkman.maven")
  jbang_v=$(cat "{{ SDK_CONFIG }}" | yq -r ".sdkman.jbang")
  gradle_v=$(cat "{{ SDK_CONFIG }}" | yq -r ".sdkman.gradle")

  sdk install java "$graal_v"
  sdk install gradle "$gradle_v"
  sdk install maven "$maven_v"
  sdk install jbang "$jbang_v"
  echo "[+] GraalVM=$graal_v, Gradle=$gradle_v, Maven=$maven_v, jbang=$jbang_v"
  sed -e "s|sdkman_auto_answer=true|sdkman_auto_answer=false|g" -i ~/.sdkman/etc/config

# Install NVM (because nodejs)
[private]
sdk_install_nvm:
  #!/usr/bin/env bash
  set -eo pipefail

  # nvm_v=$(gh release list -R nvm-sh/nvm --json "tagName,isPrerelease,isLatest" -q '.[] | select (.isPrerelease == false) |  select (.isLatest == true) | .tagName')
  #shellcheck disable=SC2002
  nvm_v=$(cat "{{ SDK_CONFIG }}" | yq -r ".nvm.version")
  if [[ -n "$DPM_SKIP_NVM_PROFILE" ]]; then
    curl -fSsL "https://raw.githubusercontent.com/nvm-sh/nvm/$nvm_v/install.sh" | PROFILE=/dev/null bash
  else
    curl -fSsL "https://raw.githubusercontent.com/nvm-sh/nvm/$nvm_v/install.sh" | bash
  fi
  #shellcheck disable=SC1090
  source ~/.nvm/nvm.sh
  nvm install --lts && nvm use --lts
  if [[ -n "$WSL_DISTRO_NAME" ]]; then
    npm install -g -y wsl-open
  fi


# Install rustup && cargo-binstall (because rust)
[private]
sdk_install_rust:
  #!/usr/bin/env bash
  set -eo pipefail

  # force rustup to not modify profile
  curl -fSsL --proto '=https' --tlsv1.2 https://sh.rustup.rs | sh -s -- -y --no-modify-path
  if [[ -z "$DPM_SKIP_RUST_PROFILE" ]]; then
    if ! grep "\.cargo\/env" "$HOME/.bashrc" >/dev/null 2>&1; then
      #shellcheck disable=SC2016
      printf '\n[[ -s "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"\n' >> "$HOME/.bashrc"
      echo -e "\n>>> DPM automatically added .cargo/env to .bashrc"
    fi
  fi

  curl -fSsL "https://github.com/cargo-bins/cargo-binstall/releases/latest/download/cargo-binstall-x86_64-unknown-linux-musl.tgz" | tar xz
  ./cargo-binstall -y --force cargo-binstall >/dev/null 2>&1
  rm -f ./cargo-binstall >/dev/null 2>&1

# Install RVM (because ruby)
[private]
sdk_install_rvm:
  #!/usr/bin/env bash
  set -eo pipefail

  gpg --keyserver keyserver.ubuntu.com --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
  if [[ -n "$DPM_SKIP_RVM_PROFILE" ]]; then
    curl -fSsL "https://get.rvm.io" | bash -s stable --ignore-dotfiles
  else
    curl -fSsL "https://get.rvm.io" | bash -s stable
  fi
  #shellcheck disable=SC1090
  source ~/.rvm/scripts/rvm
  # ruby tagname has _ so we don't derive it like the others.
  # ruby_latest=$(gh release list -R ruby/ruby | grep -i Latest | awk '{print $1}')
  #shellcheck disable=SC2002
  ruby_latest=$(cat "{{ SDK_CONFIG }}" | yq -r ".rvm.ruby")
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
    tf_v=$(cat "{{ SDK_CONFIG }}" | yq -r "$tfenv_yamlpath")
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

# Install sonar-scanner cli
[private]
sdk_install_sonar-scanner:
  #!/usr/bin/env bash
  set -eo pipefail

  mkdir -p "{{ LOCAL_SHARE }}"

  sonar_v=$(cat "{{ SDK_CONFIG }}" | yq -r ".sonar-scanner.version")

  tmpdir=$(mktemp -d -t sonar.XXXXXX)
  curl -fSsL "https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${sonar_v}.zip" -o "$tmpdir/sonar-scanner-cli.zip"
  unzip -q -d "$tmpdir" "$tmpdir/sonar-scanner-cli.zip"
  rm -rf "{{ LOCAL_SHARE }}/sonar-scanner/"
  mv "$tmpdir/sonar-scanner-${sonar_v}/" "{{ LOCAL_SHARE }}/sonar-scanner/"
  rm -rf "$tmpdir"
  if [ ! -L "$HOME/.local/bin/sonar-scanner" ]; then
    ln -s "{{ LOCAL_SHARE }}/sonar-scanner/bin/sonar-scanner" "$HOME/.local/bin/sonar-scanner"
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

  files=("{{ TOOL_CONFIG }}")
  if [[ -n "$DPM_TOOLS_ADDITIONS_YAML" ]]; then
    files+=("$DPM_TOOLS_ADDITIONS_YAML")
  fi
  # shellcheck disable=SC2016
  tools=$(yq_wrapper -p yaml -o json eval-all '. as $item ireduce ({}; . *+ $item)' "${files[@]}" | jq -c ".[]")

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
      else
        echo "[=] $binary@$version from $repo (already installed)"
        continue
      fi
    fi
  done
  write_installed

[private]
install_repos:
  #!/usr/bin/env bash
  set -eo pipefail

  yq_wrapper() {
    if ! which yq >/dev/null 2>&1; then
      gh-release-install "mikefarah/yq" "yq_linux_amd64" "$HOME/.local/bin/yq" --version v4.43.1
      "$HOME/.local/bin/yq" "$@"
    else
      yq "$@"
    fi
  }

  mkdir -p "{{ LOCAL_SHARE }}"

  files=("{{ REPO_CONFIG }}")
  if [[ -n "$DPM_REPO_ADDITIONS_YAML" ]]; then
    files+=("$DPM_REPO_ADDITIONS_YAML")
  fi
  # shellcheck disable=SC2016
  repos=$(yq_wrapper -p yaml -o json eval-all '. as $item ireduce ({}; . *+ $item)' "${files[@]}" | jq -c ".[]")

  for line in $repos; do
    repo=$(echo "$line" | jq -r ".repo")
    contents_line=$(echo "$line" | jq -r ".contents")
    source=$(echo "$contents_line" | cut -f1 -d':')
    destination=$(echo "$contents_line" | cut -f2 -d':')
    source=${source:-$destination}

    if [[ "$repo" != "null" ]]; then
      if [[ ! -d "{{ LOCAL_SHARE }}/$repo" ]]; then
        echo "[+] $repo (attempt install)"
        cd "{{ LOCAL_SHARE }}" && git clone --quiet "https://github.com/$repo" "$repo" >/dev/null
      else
        pushd "{{ LOCAL_SHARE }}/$repo" >/dev/null

        git fetch --quiet
        local=$(git rev-parse @)
        remote=$(git rev-parse '@{u}')
        base=$(git merge-base @ '@{u}')

        if [ "$local" = "$remote" ]; then
          echo "[=] $repo (already upto date)"
        elif [ "$local" = "$base" ]; then
          echo "[+] $repo (attempt update)"
          git pull --quiet --rebase
        else
          echo "[x] $repo (unexpected state)"
          exit 1
        fi

        popd >/dev/null
      fi

      if [[ "$destination" != "null" ]]; then
        if [ ! -L "$HOME/.local/bin/$destination" ]; then
          ln -s "{{ LOCAL_SHARE }}/$repo/$source" "$HOME/.local/bin/$destination"
        fi
      fi
    fi
  done

# configure github cli & extensions
ghcli:
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


# use fzf-git with fzf
fzf-git:
  #!/usr/bin/env bash
  set -eo pipefail

  SUMMARY=""
  # install fzf-tmux since it's not in the fzf tar.gz
  if [[ ! -f "{{ LOCAL_BIN }}/fzf-tmux" ]]; then
    curl -fSsL https://raw.githubusercontent.com/junegunn/fzf/master/bin/fzf-tmux -o "{{ LOCAL_BIN }}/fzf-tmux"
    chmod +x "{{ LOCAL_BIN }}/fzf-tmux"
  fi

  if [[ -z "$DPM_SKIP_FZF_PROFILE" ]]; then
    if ! grep "fzf --bash" "$HOME/.bashrc" >/dev/null 2>&1; then
      #shellcheck disable=SC2016
      printf '\n[[ -s "$HOME/.local/bin/fzf" ]] && eval $($HOME/.local/bin/fzf --bash)\n' >> "$HOME/.bashrc"
      SUMMARY+="\n>>> Added fzf --bash to .bashrc"
    fi
    if ! grep "fzf-git" "$HOME/.bashrc" >/dev/null 2>&1; then
      #shellcheck disable=SC2016
      printf '\n[[ -s "$HOME/.local/share/ubuntu-dpm/junegunn/fzf-git.sh/fzf-git.sh" ]] && source "$HOME/.local/share/ubuntu-dpm/junegunn/fzf-git.sh/fzf-git.sh"\n' >> "$HOME/.bashrc"
      SUMMARY+="\n>>> Added fzf-git.sh to .bashrc"
    fi
  fi
  echo -e "$SUMMARY"
