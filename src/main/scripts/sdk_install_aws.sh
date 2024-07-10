#!/usr/bin/env bash
set -eo pipefail

source "$(dirname "$0")/common.sh"

download_and_run_installer() {
  tmpdir=$(mktemp -d -t awscli.XXXXXX)
  curl -fSsL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "$tmpdir/awscliv2.zip"
  unzip -q -d "$tmpdir" "$tmpdir/awscliv2.zip"
  (cd "$tmpdir" && sudo ./aws/install "$@")
  rm -rf "$tmpdir"
}

case "$1" in
install)
  download_and_run_installer
  aws --version
  ;;
uninstall | rm)
  sudo rm /usr/local/bin/aws
  sudo rm /usr/local/bin/aws_completer
  sudo rm -rf /usr/local/aws-cli
  echo "Skip deleting ~/.aws (chicken mode)"
  ;;
update | upgrade)
  download_and_run_installer --update
  aws --version
  ;;
*)
  echo "Installs / updates the AWS CLI"
  echo "just sdk aws install|rm|update"
  exit 0
  ;;
esac
