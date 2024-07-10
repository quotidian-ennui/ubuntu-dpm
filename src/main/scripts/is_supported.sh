#!/usr/bin/env bash
set -eo pipefail

OS_NAME=$(uname -o | tr '[:upper:]' '[:lower:]')

if [[ "$OS_NAME" == "msys" ]]; then
  echo "Try again on WSL2+Ubuntu"
  exit 1
fi
if [[ -e "/etc/os-release" ]]; then
  # shellcheck disable=SC1091
  release=$(. /etc/os-release && echo "$ID" | tr '[:upper:]' '[:lower:]')
else
  release=$(lsb_release -si | tr '[:upper:]' '[:lower:]') || true
fi
case "$release" in
ubuntu | debian) ;;
*)
  echo "Try again on Ubuntu or Debian"
  exit 1
  ;;
esac
