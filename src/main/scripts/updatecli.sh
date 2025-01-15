#!/usr/bin/env bash
set -eo pipefail

#shellcheck disable=SC1091
source "$(dirname "$0")/common.sh"

#shellcheck disable=SC2016
TOOL_JQ_FILTER='
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
#shellcheck disable=SC2016
ARCHIVE_JQ_FILTER='
    {
      "config_file": $cfg,
      "repo": .value.repo,
      "yamlpath": (if .value.updatecli.yamlpath == null then "$.\(.key).version.github_tag" else .value.updatecli.yamlpath end),
      "pattern": (if .value.updatecli.pattern == null then "*" else .value.updatecli.pattern end),
      "kind": (if .value.updatecli.kind == null then "semver" else .value.updatecli.kind end),
      "trim_prefix": .value.version.strip_prefix
    }
    | with_entries(if .value == null then empty else . end)
  '

exec_updatecli() {
  local config_file="$1"
  local tmpdir="$2"
  local filter="$3"
  local template="$4"

  shift 4
  if [[ -n "$config_file" && -f "$config_file" ]]; then
    # shellcheck disable=SC2002
    cat "$config_file" | yq -p yaml -o json | jq -c "to_entries | .[]" | while read -r line; do
      values=$(mktemp --tmpdir="$tmpdir" updatecli-values.XXXXXX.yml)
      hasRepo=$(echo "$line" | jq -r ".value.repo")
      if [[ "$hasRepo" != "null" ]]; then
        echo "$line" | jq --arg cfg "$config_file" "$filter" | yq -P -o yaml >"$values"
        GITHUB_TOKEN=$GITHUB_TOKEN updatecli "$@" --values "$values" -c "$template"
      fi
    done
  fi
}

if [[ -z "$GITHUB_TOKEN" ]]; then
  GITHUB_TOKEN=$(gh auth token)
fi

tmpdir=$(mktemp -d -t updatecli.XXXXXX)
exec_updatecli "$TOOL_CONFIG" "$tmpdir" "$TOOL_JQ_FILTER" "$UPDATECLI_TEMPLATE" "$@"
exec_updatecli "$ARCHIVE_CONFIG" "$tmpdir" "$ARCHIVE_JQ_FILTER" "$UPDATECLI_ARCHIVE_TEMPLATE" "$@"
case "$UPDATE_TYPE" in
additions | local | personal) ;;
*)
  GITHUB_TOKEN=$GITHUB_TOKEN updatecli "$@"
  ;;
esac

rm -rf "$tmpdir"
