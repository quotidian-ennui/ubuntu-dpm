#!/usr/bin/env bash
# To make it easy, these are just copy-pasta of the appropriate snippets from the documentation
# for installing from apt-repos from the tool website.
# I wouldn't have mixed & matched wget + curl...

set -eo pipefail

PRE_REQ_TOOLS="apt-transport-https ca-certificates curl gnupg wget software-properties-common"
DOCKER_TOOL_LIST="docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
BASELINE_TOOL_LIST="vim nfs-common unison direnv git zoxide jq tidy kubectl helm gh jq pipx trivy net-tools zip unzip"

DOCKER_USE_WINCREDS='
{
  "credsStore": "wincred.exe"
}
'

WSL_CONF='
[boot]
systemd=true
'

download_keyrings(){
  local url=$1
  local name=$2
  local file="/usr/share/keyrings/$name.gpg"
  curl -fsSL "$url" | gpg --no-tty --batch --dearmor | sudo dd of="$file" && sudo chmod go+r "$file"
}

# docker
repo_docker() {
  download_keyrings "https://download.docker.com/linux/$(distro_name)/gpg" "docker"
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/$(distro_name) \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
}

# trivy
repo_trivy() {
  download_keyrings "https://aquasecurity.github.io/trivy-repo/deb/public.key" "trivy"
  echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/trivy.list
}

# proget makedeb (Just)
repo_prebuilt() {
  download_keyrings "https://proget.makedeb.org/debian-feeds/prebuilt-mpr.pub" "prebuilt-mpr"
  echo "deb [arch=all,$(dpkg --print-architecture) signed-by=/usr/share/keyrings/prebuilt-mpr.gpg] https://proget.makedeb.org prebuilt-mpr $(lsb_release -cs)" | sudo tee /etc/apt/sources.list.d/prebuilt-mpr.list
}

# kubectl
repo_kubectl() {
  download_keyrings https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key "kubernetes"
  echo 'deb [signed-by=/usr/share/keyrings/kubernetes.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
}

# helm
repo_helm() {
  download_keyrings https://baltocdn.com/helm/signing.asc "helm"
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
}

# gh cli
repo_ghcli() {
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli.gpg && sudo chmod go+r /usr/share/keyrings/githubcli.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list
}

# wsl utilities
repo_wslutilities() {
  download_keyrings https://pkg.wslutiliti.es/public.key  "wslutilities"
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/wslutilities.gpg] https://pkg.wslutiliti.es/debian $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/wslutilities.list
}

install_vscode() {
  if [[ -z "$WSL_DISTRO_NAME" && -n "${XDG_CURRENT_DESKTOP}" ]]; then
    vscode_deb=$(mktemp --tmpdir vscode.XXXXX.deb)
    wget -q -O "$vscode_deb" "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64"
    sudo apt -y install "$vscode_deb"
  fi
}

install_docker() {
  if [[ -z "$SKIP_DOCKER" ]]
  then
    sudo apt -y install $DOCKER_TOOL_LIST
    sudo groupadd docker || true
    sudo usermod -aG docker $USER
    # If we're on windows then we can use the docker credential helper
    if [[ -n "$WSL_DISTRO_NAME" ]]; then
      wincred_version=$(curl -fsSL -o /dev/null -w "%{url_effective}" https://github.com/docker/docker-credential-helpers/releases/latest | xargs basename)
      mkdir -p ~/.local/bin
      mkdir -p ~/.docker
      curl -fSsL -o ~/.local/bin/docker-credential-wincred.exe \
        "https://github.com/docker/docker-credential-helpers/releases/download/${wincred_version}/docker-credential-wincred-${wincred_version}.windows-$(dpkg --print-architecture).exe"
      chmod +x ~/.local/bin/docker-credential-wincred.exe
      echo $DOCKER_USE_WINCREDS > ~/.docker/config.json
      if [[ ! -f /etc/wsl.conf ]]; then
        sudo echo $WSL_CONF > /etc/wsl.conf
        echo ">>> /etc/wsl.conf modified, you need to restart WSL"
      fi
    fi
  fi
}

action_help() {
  cat << EOF

New Ubuntu Machine bootstrap; some attention required

Usage: $(basename "$0") repos | baseline | help
  repos      : First things first
  baseline   : Setup baseline tools required
  # After this there's 'just xxx'
  help       : Show this help

EOF
 exit 1
}

action_repos() {
  sudo apt install -y $PRE_REQ_TOOLS
  repo_prebuilt
  repo_kubectl
  repo_helm
  repo_ghcli
  repo_docker
  repo_trivy
  if [[ "$(distro_name)" == "ubuntu" ]]; then
    sudo add-apt-repository -y ppa:git-core/ppa
  fi
  if [[ -n "$WSL_DISTRO_NAME" ]]; then
    repo_wslutilities
  fi
  sudo apt update
}

action_baseline() {
  sudo apt install -y $BASELINE_TOOL_LIST
  if ! which just >/dev/null 2>&1; then
    sudo apt install -y just
  fi
  pipx install gh-release-install
  if [[ -n "$WSL_DISTRO_NAME" ]]; then
    sudo apt install -y wslu
    # Having wslview in debian & ubuntu can cause trouble with binfmt
    # stop systemctl from starting binfmt.
    # c.f. : https://github.com/microsoft/WSL/issues/8843
    # https://github.com/microsoft/WSL/issues/8986
    sudo systemctl mask systemd-binfmt.service
    # Could also 'force' it to work.
    # echo ":WSLInterop:M::MZ::/init:PF" | sudo tee /usr/lib/binfmt.d/WSLInterop.conf
    # sudo apt install binfmt-support
    # sudo systemctl restart binfmt-support
    sudo systemctl restart systemd-binfmt
  fi
  install_docker
  install_vscode
}

distro_name() {
  if [[ -e "/etc/os-release" ]]; then
    release=$(. /etc/os-release && echo "$ID" | tr '[:upper:]' '[:lower:]')
  else
    release=$(lsb_release -si | tr '[:upper:]' '[:lower:]') || true
  fi
  echo $release
}

if [[ "$(uname -o | tr '[:upper:]' '[:lower:]')" == "msys" ]]; then echo "Try again on WSL2+Ubuntu"; exit 1; fi
case "$(distro_name)" in
  ubuntu|debian) ;;
  *) echo "Try again on Ubuntu or Debian"; exit 1;;
esac

ACTION=$1 || true
ACTION=${ACTION:-"help"}
case $ACTION in
  repos|baseline|help)
    ;;
  *)
    ACTION="help"
    ;;
esac

action_"$ACTION"
