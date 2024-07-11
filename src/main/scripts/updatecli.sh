#!/usr/bin/env bash
set -eo pipefail

source "$(dirname "$0")/common.sh"

JQ_FILTER='
    {
      "repo": .value.repo,
      "yamlpath": (if .value.updatecli.yamlpath == null then "$.\(.key).version" else .value.updatecli.yamlpath end),
      "pattern": (if .value.updatecli.pattern == null then "*" else .value.updatecli.pattern end),
      "kind": (if .value.updatecli.kind == null then "semver" else .value.updatecli.kind end),
      "trim_prefix": .value.updatecli.trim_prefix
    }
    | with_entries(if .value == null then empty else . end)
  '

if [[ -z "$GITHUB_TOKEN" ]]; then
  GITHUB_TOKEN=$(gh auth token)
fi

tmpdir=$(mktemp -d -t updatecli.XXXXXX)
# shellcheck disable=SC2002
cat "$TOOL_CONFIG" | yq -p yaml -o json | jq -c "to_entries | .[]" | while read -r line; do
  values=$(mktemp --tmpdir="$tmpdir" updatecli-values.XXXXXX.yml)
  hasRepo=$(echo "$line" | jq -r ".value.repo")
  if [[ "$hasRepo" != "null" ]]; then
    echo "$line" | jq "$JQ_FILTER" | yq -P -o yaml >"$values"
    GITHUB_TOKEN=$GITHUB_TOKEN updatecli "$@" --values "$values" -c "$UPDATECLI_TEMPLATE"
  fi
done
GITHUB_TOKEN=$GITHUB_TOKEN updatecli "$@"
rm -rf "$tmpdir"
