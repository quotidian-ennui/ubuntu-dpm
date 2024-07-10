#!/usr/bin/env bash
# shellcheck disable=SC2016
# shellcheck disable=SC2002

set -eo pipefail
source "$(dirname "$0")/common.sh"

rm -f "$LOCAL_BIN/goenv"
if [[ -d "$GOENV_ROOT" ]]; then
  cd "$GOENV_ROOT" && git pull --rebase
else
  git clone "https://github.com/go-nv/goenv.git" "$GOENV_ROOT"
fi
#shellcheck disable=SC1083
ln -s "$GOENV_ROOT/bin/"* "$LOCAL_BIN"
case "$1" in
install | latest)
  if [[ -z "$DPM_SKIP_GO_PROFILE" ]]; then
    if ! grep -q 'export GOENV_ROOT="$HOME/.goenv"' ~/.bashrc 2>/dev/null; then
      {
        printf '\nif [[ -d "$HOME/.goenv" ]]; then'
        printf '\n  export GOENV_ROOT="$HOME/.goenv"'
        printf '\n  eval "$($GOENV_ROOT/bin/goenv init -)"'
        printf '\nfi'
      } >>~/.bashrc
    fi
  fi
  go_v=$(cat "$SDK_CONFIG" | yq -r ".golang.version")
  "$GOENV_ROOT/bin/goenv" install -s "$go_v"
  "$GOENV_ROOT/bin/goenv" global "$go_v"
  "$GOENV_ROOT/bin/goenv" versions
  ;;
*)
  echo ">>> goenv updated"
  ;;
esac
