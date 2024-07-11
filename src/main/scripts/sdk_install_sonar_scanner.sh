#!/usr/bin/env bash
#shellcheck disable=SC2002
set -eo pipefail

source "$(dirname "$0")/common.sh"

sonar_v=$(cat "$SDK_CONFIG" | yq -r ".sonar-scanner.version")

tmpdir=$(mktemp -d -t sonar.XXXXXX)
curl -fSsL "https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${sonar_v}.zip" -o "$tmpdir/sonar-scanner-cli.zip"
unzip -q -d "$tmpdir" "$tmpdir/sonar-scanner-cli.zip"
rm -rf "$LOCAL_SHARE/sonar-scanner/"
mv "$tmpdir/sonar-scanner-${sonar_v}/" "$LOCAL_SHARE/sonar-scanner/"
rm -rf "$tmpdir"
if [ ! -L "$LOCAL_BIN/sonar-scanner" ]; then
  ln -s "$LOCAL_SHARE/sonar-scanner/bin/sonar-scanner" "$LOCAL_BIN/sonar-scanner"
fi
