#!/usr/bin/env bash
set -eo pipefail
#shellcheck disable=SC1091
source "$(dirname "$0")/common.sh"

SUMMARY=""
# install fzf-tmux since it's not in the fzf tar.gz
if [[ ! -f "$LOCAL_BIN/fzf-tmux" ]]; then
  curl -fSsL https://raw.githubusercontent.com/junegunn/fzf/master/bin/fzf-tmux -o "$LOCAL_BIN/fzf-tmux"
  chmod +x "$LOCAL_BIN/fzf-tmux"
fi

if [[ -z "$DPM_SKIP_FZF_PROFILE" ]]; then
  if ! grep "fzf --bash" "$DPM_BASH_PROFILE_FILE" >/dev/null 2>&1; then
    #shellcheck disable=SC2016
    printf '\n[[ -s "$HOME/.local/bin/fzf" ]] && eval $($HOME/.local/bin/fzf --bash)\n' >>"$DPM_BASH_PROFILE_FILE"
    SUMMARY+="\n>>> Added fzf --bash to $DPM_BASH_PROFILE_FILE"
  fi
  if ! grep "fzf-git" "$DPM_BASH_PROFILE_FILE" >/dev/null 2>&1; then
    #shellcheck disable=SC2016
    printf '\n[[ -s "$HOME/.local/share/ubuntu-dpm/junegunn/fzf-git.sh/fzf-git.sh" ]] && source "$HOME/.local/share/ubuntu-dpm/junegunn/fzf-git.sh/fzf-git.sh"\n' >>"$HOME/.bashrc"
    SUMMARY+="\n>>> Added fzf-git.sh to $DPM_BASH_PROFILE_FILE"
  fi
fi
echo -e "$SUMMARY"
