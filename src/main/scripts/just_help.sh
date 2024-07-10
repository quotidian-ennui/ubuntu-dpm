#!/usr/bin/env bash
# $1 = the module (for logging)
# $2 = the prefix (for filtering tasks in the just file

set -eo pipefail
source "$(dirname "$0")/common.sh"

module=$1
filter=$2
jq_filter="^$filter.*"

JUSTFILE_JSON=$(just --dump-format json --dump --unstable)
tasks=$(echo "$JUSTFILE_JSON" | jq --arg jq_filter "$jq_filter" -c '.recipes | .[] | select( .name | test($jq_filter)) | { "recipe" : .name, "doc": .doc }')
echo "just $module <action>"
while IFS= read -r line; do
  recipe=$(echo "$line" | jq -r '.recipe')
  doc=$(echo "$line" | jq -r '.doc')
  echo "  ${recipe/$filter/}|$doc"
done <<<"$tasks" | column -s"|" -t
