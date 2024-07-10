#!/usr/bin/env bash
#Disable redundant cat throughout the scrsipt.
#shellcheck disable=SC2002
set -eo pipefail
source "$(dirname "$0")/common.sh"

if [[ ! -d "$HOME/.sdkman" ]]; then
  # It does feel that if we already have SDKMAN installed then
  # we could execute sdk selfupdate & sdk upgrade
  if [[ -n "$DPM_SKIP_JAVA_PROFILE" ]]; then
    curl -fSsL "https://get.sdkman.io?rcupdate=false" | bash
  else
    curl -fSsL "https://get.sdkman.io" | bash
  fi
fi
# This is a bit of a hack to avoid the interactive prompt but setting
# it on the commandline doesn't always work.
sed -e "s|sdkman_auto_answer=false|sdkman_auto_answer=true|g" -i ~/.sdkman/etc/config
#shellcheck disable=SC1090
source ~/.sdkman/bin/sdkman-init.sh

graal_v=$(cat "$SDK_CONFIG" | yq -r ".sdkman.java")
maven_v=$(cat "$SDK_CONFIG" | yq -r ".sdkman.maven")
jbang_v=$(cat "$SDK_CONFIG" | yq -r ".sdkman.jbang")
gradle_v=$(cat "$SDK_CONFIG" | yq -r ".sdkman.gradle")

sdk install java "$graal_v"
sdk install gradle "$gradle_v"
sdk install maven "$maven_v"
sdk install jbang "$jbang_v"
echo "[+] GraalVM=$graal_v, Gradle=$gradle_v, Maven=$maven_v, jbang=$jbang_v"
sed -e "s|sdkman_auto_answer=true|sdkman_auto_answer=false|g" -i ~/.sdkman/etc/config
