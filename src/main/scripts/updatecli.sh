#!/usr/bin/env bash
set -eo pipefail

#shellcheck disable=SC1091
source "$(dirname "$0")/common.sh"

#shellcheck disable=SC2016
JQ_FILTER='
    {
      "config_file": $cfg,
      "repo": .value.repo,
      "yamlpath": (if .value.updatecli.yamlpath == null then "$.\(.key).version" else .value.updatecli.yamlpath end),
      "pattern": (if .value.updatecli.pattern == null then "*" else .value.updatecli.pattern end),
      "kind": (if .value.updatecli.kind == null then "semver" else .value.updatecli.kind end),
      "trim_prefix": .value.updatecli.trim_prefix
    }
    | with_entries(if .value == null then empty else . end)
  '

exec_updatecli() {
  local config_file="$1"
  local tmpdir="$2"

  shift 2
  if [[ -n "$config_file" && -f "$config_file" ]]; then
    # shellcheck disable=SC2002
    cat "$config_file" | yq -p yaml -o json | jq -c "to_entries | .[]" | while read -r line; do
      values=$(mktemp --tmpdir="$tmpdir" updatecli-values.XXXXXX.yml)
      hasRepo=$(echo "$line" | jq -r ".value.repo")
      if [[ "$hasRepo" != "null" ]]; then
        echo "$line" | jq --arg cfg "$config_file" "$JQ_FILTER" | yq -P -o yaml >"$values"
        GITHUB_TOKEN=$GITHUB_TOKEN updatecli "$@" --values "$values" -c "$UPDATECLI_TEMPLATE"
      fi
    done
  fi
}

if [[ -z "$GITHUB_TOKEN" ]]; then
  GITHUB_TOKEN=$(gh auth token)
fi

tmpdir=$(mktemp -d -t updatecli.XXXXXX)
exec_updatecli "$TOOL_CONFIG" "$tmpdir" "$@"
case "$UPDATE_TYPE" in
additions | local | personal) ;;
*)
  GITHUB_TOKEN=$GITHUB_TOKEN updatecli "$@"
  ;;
esac

rm -rf "$tmpdir"
