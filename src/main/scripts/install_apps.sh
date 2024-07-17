#!/usr/bin/env bash
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

check_prereqs() {
  if ! which bsdtar >/dev/null; then
    echo "No bsdtar -> apt install libarchive-tools"
    exit 1
  fi
  if ! gh auth status >/dev/null 2>&1; then
    gh auth login -h github.com
  fi
}

declare -A installed
check_prereqs
read_installed
tmpdir=$(mktemp -d -t appzip.XXXXXX)
files=("$APPZIP_CONFIG")
if [[ -n "$DPM_APPZIP_ADDITIONS_YAML" ]]; then
  files+=("$DPM_APPZIP_ADDITIONS_YAML")
fi
# shellcheck disable=SC2016
repos=$(yq_wrapper -p yaml -o json eval-all '. as $item ireduce ({}; . *+ $item)' "${files[@]}" | jq -c ".[]")

for line in $repos; do
  repo=$(echo "$line" | jq -r ".repo")
  tag=$(echo "$line" | jq -r ".version.github_tag")
  stripPrefix=$(echo "$line" | jq -r ".version.strip_prefix")
  artifact=$(echo "$line" | jq -r ".artifact")
  path_in_zip=$(echo "$line" | jq -r "select( .path_in_zip != null ) | .path_in_zip")
  version=${tag#"$stripPrefix"}
  artifact=${artifact/"{version}"/"$version"}
  artifact=${artifact/"{tag}"/"$tag"}

  stripComponentCount="0"
  if [[ -n "$path_in_zip" ]]; then
    path_in_zip=${path_in_zip/"{version}"/"$version"}
    path_in_zip=${path_in_zip/"{tag}"/"$tag"}
    stripComponentCount=$(echo "$path_in_zip" | awk -F'/' '{print NF}')
  fi

  if [[ "$repo" != "null" ]]; then
    if [[ "${installed[$repo]}" != "$version" || ! -d "$LOCAL_SHARE/$repo" ]]; then
      # Check the tag exists
      if gh release list -R "$repo" --json "tagName" -q '.[] | .tagName' | grep "$tag" >/dev/null 2>&1; then
        echo "[+] $repo (attempt install)"
        pushd "$tmpdir" >/dev/null
        gh release download "$tag" -R "$repo" --pattern "$artifact"
        mkdir -p "$LOCAL_SHARE/$repo"
        if [[ "$stripComponentCount" -gt "0" ]]; then
          bsdtar -xf "$tmpdir/$artifact" --directory "$LOCAL_SHARE/$repo" --strip-components "$stripComponentCount"
        else
          bsdtar -xf "$tmpdir/$artifact" --directory "$LOCAL_SHARE/$repo"
        fi
        ## How do we add ~/.local/share/ubuntu-dpm/liquibase/liquibase to the path?
        popd >/dev/null
        installed[$repo]="$version"
      else
        echo "[!] $repo ($tag does not exist)"
      fi
    else
      echo "[=] $repo (already installed)"
    fi
  fi
done
write_installed
if [[ -d "$tmpdir" ]]; then
  rm -rf "$tmpdir"
fi
