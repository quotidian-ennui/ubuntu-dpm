#!/usr/bin/env bash
# To make it easy, these are just copy-pasta of the appropriate snippets from the documentation
# for installing from apt-repos from the tool website.
# I wouldn't have mixed & matched wget + curl...

set -eo pipefail

PRE_REQ_TOOLS="apt-transport-https ca-certificates curl gnupg wget software-properties-common"
DOCKER_TOOL_LIST="docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
BASELINE_TOOL_LIST="vim nfs-common unison direnv git zoxide jq tidy kubectl helm gh jq pipx trivy net-tools zip unzip"
JOB_SUMMARY=""

# shellcheck disable=SC2089
DOCKER_USE_WINCREDS='
{
  "credsStore": "wincred.exe"
}
'

WSL_CONF='
[boot]
systemd=true
'

append_with_newline() {
  printf -v "$1" '%s\n%s' "${!1}" "$2"
}

download_keyrings() {
  local url=$1
  local name=$2
  local file="/usr/share/keyrings/$name.gpg"
  curl -fsSL "$url" | gpg --no-tty --batch --dearmor | sudo dd of="$file" && sudo chmod go+r "$file"
}

# docker
repo_docker() {
  local distro_name="$1"
  download_keyrings "https://download.docker.com/linux/$distro_name/gpg" "docker"
  # shellcheck disable=SC1091
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/$distro_name \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" |
    sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
}

# trivy.
# some shenanigans because trivy doesn't always update its repo releases
# in good time.
# distro-info is available in ubuntu, but must be explicitly installed in debian
# probably not worth it, but if we did we could...
# distro-info --supported | sed -n "/$(lsb_release -sc)/q;p" | tac
# and iterate.
repo_trivy() {
  download_keyrings "https://aquasecurity.github.io/trivy-repo/deb/public.key" "trivy"
  local trivy_fallback=""
  local current_release=""
  current_release=$(lsb_release -sc)
  if [[ "$1" == "ubuntu" ]]; then
    # focal -> jammy -> noble
    trivy_fallback="jammy"
  else
    # buster -> bullseye -> bookworm
    trivy_fallback="bullseye"
  fi
  local repo_name="$current_release"
  if ! curl -fsSL "https://raw.githubusercontent.com/aquasecurity/trivy-repo/main/deb/dists/$current_release/Release" >/dev/null 2>&1; then
    repo_name="$trivy_fallback"
  fi
  echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb $repo_name main" | sudo tee /etc/apt/sources.list.d/trivy.list
}

# kubectl
repo_kubectl() {
  download_keyrings https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key "kubernetes"
  echo 'deb [signed-by=/usr/share/keyrings/kubernetes.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
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
  download_keyrings https://pkg.wslutiliti.es/public.key "wslutilities"
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
  if [[ -z "$SKIP_DOCKER" && -z "$DPM_SKIP_DOCKER" ]]; then
    # shellcheck disable=SC2086
    sudo apt -y install $DOCKER_TOOL_LIST
    sudo groupadd docker || true
    sudo usermod -aG docker "$USER"
    # If we're on windows then we can use the docker credential helper
    if [[ -n "$WSL_DISTRO_NAME" ]]; then
      wincred_version=$(curl -fsSL -o /dev/null -w "%{url_effective}" https://github.com/docker/docker-credential-helpers/releases/latest | xargs basename)
      mkdir -p ~/.local/bin
      mkdir -p ~/.docker
      curl -fSsL -o ~/.local/bin/docker-credential-wincred.exe \
        "https://github.com/docker/docker-credential-helpers/releases/download/${wincred_version}/docker-credential-wincred-${wincred_version}.windows-$(dpkg --print-architecture).exe"
      chmod +x ~/.local/bin/docker-credential-wincred.exe
      echo "$DOCKER_USE_WINCREDS" >~/.docker/config.json
      if [[ ! -f /etc/wsl.conf ]]; then
        echo "$WSL_CONF" | sudo tee /etc/wsl.conf
        append_with_newline JOB_SUMMARY ">>> /etc/wsl.conf modified, you need to restart WSL"
      fi
    fi
  fi
}

action_help() {
  cat <<EOF

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
  local distro_name="$1"
  # shellcheck disable=SC2086
  sudo apt install -y $PRE_REQ_TOOLS
  repo_kubectl "$distro_name"
  repo_helm "$distro_name"
  repo_ghcli "$distro_name"
  repo_docker "$distro_name"
  repo_trivy "$distro_name"
  if [[ "$distro_name" == "ubuntu" ]]; then
    sudo add-apt-repository -y ppa:git-core/ppa
  fi
  if [[ -n "$WSL_DISTRO_NAME" && "$distro_name" == "debian" ]]; then
    repo_wslutilities
  fi
  sudo apt update
}

action_baseline() {
  local distro_name="$1"
  # shellcheck disable=SC2086
  sudo apt install -y $BASELINE_TOOL_LIST
  pipx install gh-release-install
  if ! which just >/dev/null 2>&1; then
    # Oneshot install that we know works for us.
    "$HOME/.local/bin/gh-release-install" "casey/just" "just-1.25.2-x86_64-unknown-linux-musl.tar.gz" "$HOME/.local/bin/just" --extract just
  fi
  install_vscode "$distro_name"
  install_docker "$distro_name"
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
    # sudo systemctl restart systemd-binfmt || true
    append_with_newline JOB_SUMMARY ">>> You might need to restart WSL for binfmt changes to take effect"
  fi
  # Get 'column' etc.
  if [[ "$distro_name" == "debian" ]]; then
    sudo apt install -y bsdextrautils
  fi
}

distro_name() {
  if [[ -e "/etc/os-release" ]]; then
    # shellcheck disable=SC1091
    release=$(. /etc/os-release && echo "$ID" | tr '[:upper:]' '[:lower:]')
  else
    release=$(lsb_release -si | tr '[:upper:]' '[:lower:]') || true
  fi
  echo "$release"
}

DISTRO_NAME=$(distro_name)

if [[ "$(uname -o | tr '[:upper:]' '[:lower:]')" == "msys" ]]; then
  echo "Try again on WSL2+Ubuntu"
  exit 1
fi
case "$DISTRO_NAME" in
ubuntu | debian) ;;
*)
  echo "Try again on Ubuntu or Debian"
  exit 1
  ;;
esac

ACTION=$1 || true
ACTION=${ACTION:-"help"}
case $ACTION in
repos | baseline | help) ;;
*)
  ACTION="help"
  ;;
esac

action_"$ACTION" "$DISTRO_NAME"
printf "%s\n" "$JOB_SUMMARY"
