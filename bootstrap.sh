#!/usr/bin/env bash
# To make it easy, these are just copy-pasta of the appropriate snippets from the documentation
# for installing from apt-repos from the tool website.
# I wouldn't have mixed & matched wget + curl...

set -eo pipefail

# docker
repo_docker() {
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
}

# trivy
repo_trivy() {
  wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null
  echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
}

# proget makedeb (Just)
repo_prebuilt() {
  wget -qO - 'https://proget.makedeb.org/debian-feeds/prebuilt-mpr.pub' | gpg --dearmor | sudo tee /usr/share/keyrings/prebuilt-mpr-archive-keyring.gpg 1> /dev/null
  echo "deb [arch=all,$(dpkg --print-architecture) signed-by=/usr/share/keyrings/prebuilt-mpr-archive-keyring.gpg] https://proget.makedeb.org prebuilt-mpr $(lsb_release -cs)" | sudo tee /etc/apt/sources.list.d/prebuilt-mpr.list
}

# kubectl
repo_kubectl() {
  curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
}

# helm
repo_helm() {
  curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
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

install_apt_repos() {
  repo_prebuilt
  repo_kubectl
  repo_helm
  repo_ghcli
  repo_docker
  repo_trivy
  sudo add-apt-repository -y ppa:git-core/ppa
  sudo apt update
}

if [[ "$(uname -o | tr '[:upper:]' '[:lower:]')" == "msys" ]]; then echo "Try again on WSL2+Ubuntu"; exit 1; fi
case "$(lsb_release -si)" in
  Ubuntu) ;;
  *) echo "Try again on Ubuntu"; exit 1;;
esac

sudo apt install -y apt-transport-https ca-certificates curl gnupg wget software-properties-common lsb_release
install_apt_repos
install_vscode
sudo apt install -y just direnv git zoxide jq tidy
