#!/usr/bin/env bash
# Pre-Reqs:
#  sudo apt install jq pipx
#  pipx install gh-release-install (https://github.com/jooola/gh-release-install)
# We're using SNAP which might require systemd
# In /etc/wsl.conf in the linux distro
# [boot]
# systemd=true
# and then do the wsl --shutdown restart dance.
set -eo pipefail
source "$(dirname "$0")/common.sh"

write_installed() {
  {
    for i in "${!installed[@]}"; do
      echo "$i=${installed[$i]}"
    done
  } >"$INSTALLED_VERSIONS"
}

read_installed() {
  if [[ -f "$INSTALLED_VERSIONS" ]]; then
    # shellcheck disable=SC1097
    while IFS== read -r key value; do
      installed[$key]=$value
    done <"$INSTALLED_VERSIONS"
  fi
}

declare -A installed
read_installed

files=("$TOOL_CONFIG")
if [[ -n "$DPM_TOOLS_ADDITIONS_YAML" ]]; then
  files+=("$DPM_TOOLS_ADDITIONS_YAML")
fi
# shellcheck disable=SC2016
tools=$(yq_wrapper -p yaml -o json eval-all '. as $item ireduce ({}; . *+ $item)' "${files[@]}" | jq -c ".[]")

for line in $tools; do
  repo=$(echo "$line" | jq -r ".repo")
  version=$(echo "$line" | jq -r ".version")
  artifact=$(echo "$line" | jq -r ".artifact")
  contents_line=$(echo "$line" | jq -r ".contents")
  extract=$(echo "$contents_line" | cut -f1 -d':')
  binary=$(echo "$contents_line" | cut -f2 -d':')
  binary=${binary:-$extract}
  if [[ -n "$extract" ]]; then
    extract_cmdline="--extract $extract"
  else
    extract_cmdline=""
  fi
  if [[ "$repo" != "null" ]]; then
    if [[ "${installed[$binary]}" != "$version" || ! -x "$LOCAL_BIN/$binary" ]]; then
      echo "[+] $binary@$version from $repo (attempt install)"
      # since extract_cmdline needs to be expanded.
      # shellcheck disable=SC2086
      gh-release-install "$repo" "$artifact" "$LOCAL_BIN/$binary" --version "$version" $extract_cmdline
      installed[$binary]="$version"
    else
      echo "[=] $binary@$version from $repo (already installed)"
      continue
    fi
  fi
done
write_installed
