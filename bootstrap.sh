#!/usr/bin/env bash
# To make it easy, these are just copy-pasta of the appropriate snippets from the documentation
# for installing from apt-repos from the tool website.
# I wouldn't have mixed & matched wget + curl...

set -eo pipefail

PRE_REQ_TOOLS="apt-transport-https ca-certificates curl gnupg wget software-properties-common"
DOCKER_TOOL_LIST="docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
BASELINE_TOOL_LIST="vim nfs-common unison just direnv git zoxide jq tidy kubectl helm gh jq python3-pip trivy net-tools zip unzip"

DOCKER_USE_WINCREDS='
{
  "credsStore": "wincred.exe"
}
'

# docker
repo_docker() {
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
}

# trivy
repo_trivy() {
  wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo gpg --dearmor --batch --yes -o /usr/share/keyrings/trivy.gpg
  echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/trivy.list
}

# proget makedeb (Just)
repo_prebuilt() {
  wget -qO - 'https://proget.makedeb.org/debian-feeds/prebuilt-mpr.pub' | sudo gpg --dearmor --batch --yes -o /usr/share/keyrings/prebuilt-mpr-archive-keyring.gpg
  echo "deb [arch=all,$(dpkg --print-architecture) signed-by=/usr/share/keyrings/prebuilt-mpr-archive-keyring.gpg] https://proget.makedeb.org prebuilt-mpr $(lsb_release -cs)" | sudo tee /etc/apt/sources.list.d/prebuilt-mpr.list
}

# kubectl
repo_kubectl() {
  curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
}

# helm
repo_helm() {
  curl -fsSL https://baltocdn.com/helm/signing.asc | sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/helm.gpg 
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
}

# gh cli
repo_ghcli() {
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list
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
      curl -fSsL -o ~/.local/bin/docker-credential-wincred.exe \
        "https://github.com/docker/docker-credential-helpers/releases/download/${wincred_version}/docker-credential-wincred-${wincred_version}.windows-$(dpkg --print-architecture).exe"
      chmod +x ~/.local/bin/docker-credential-wincred.exe
      echo $DOCKER_USE_WINCREDS > ~/.docker/config.json
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
  sudo add-apt-repository -y ppa:git-core/ppa
  sudo apt update
}

action_baseline() {
  sudo apt install -y $BASELINE_TOOL_LIST
  if ! which yq >/dev/null 2>&1; then
    sudo snap install yq
  fi
  pip install gh-release-install
  install_docker
  install_vscode
}

if [[ "$(uname -o | tr '[:upper:]' '[:lower:]')" == "msys" ]]; then echo "Try again on WSL2+Ubuntu"; exit 1; fi
case "$(lsb_release -si)" in
  Ubuntu) ;;
  *) echo "Try again on Ubuntu"; exit 1;;
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
