#!/usr/bin/env bash
set -eo pipefail

source "$(dirname "$0")/common.sh"

# force rustup to not modify profile
curl -fSsL --proto '=https' --tlsv1.2 https://sh.rustup.rs | sh -s -- -y --no-modify-path
if [[ -z "$DPM_SKIP_RUST_PROFILE" ]]; then
  if ! grep "\.cargo\/env" "$HOME/.bashrc" >/dev/null 2>&1; then
    #shellcheck disable=SC2016
    printf '\n[[ -s "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"\n' >>"$HOME/.bashrc"
    echo -e "\n>>> DPM automatically added .cargo/env to .bashrc"
  fi
fi

curl -fSsL "https://github.com/cargo-bins/cargo-binstall/releases/latest/download/cargo-binstall-x86_64-unknown-linux-musl.tgz" | tar xz
./cargo-binstall -y --force cargo-binstall >/dev/null 2>&1
rm -f ./cargo-binstall >/dev/null 2>&1
