#!/usr/bin/env bash
set -eo pipefail
source "$(dirname "$0")/common.sh"

files=("$REPO_CONFIG")
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
    if [[ ! -d "$LOCAL_SHARE/$repo" ]]; then
      echo "[+] $repo (attempt install)"
      cd "$LOCAL_SHARE" && git clone --quiet "https://github.com/$repo" "$repo" >/dev/null
    else
      pushd "$LOCAL_SHARE/$repo" >/dev/null

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
      if [ ! -L "$LOCAL_BIN/$destination" ]; then
        ln -s "$LOCAL_SHARE/$repo/$source" "$LOCAL_BIN/$destination"
      fi
    fi
  fi
done
