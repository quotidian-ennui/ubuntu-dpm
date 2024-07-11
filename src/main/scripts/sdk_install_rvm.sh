#!/usr/bin/env bash
set -eo pipefail

source "$(dirname "$0")/common.sh"

gpg --keyserver keyserver.ubuntu.com --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
if [[ -n "$DPM_SKIP_RVM_PROFILE" ]]; then
  curl -fSsL "https://get.rvm.io" | bash -s stable --ignore-dotfiles
else
  curl -fSsL "https://get.rvm.io" | bash -s stable
fi
#shellcheck disable=SC1090
source ~/.rvm/scripts/rvm
# ruby tagname has _ so we don't derive it like the others.
# ruby_latest=$(gh release list -R ruby/ruby | grep -i Latest | awk '{print $1}')
#shellcheck disable=SC2002
ruby_latest=$(cat "$SDK_CONFIG" | yq -r ".rvm.ruby")
ruby_v=${ruby_latest#"v"}
echo "Ruby $ruby_v" && rvm install ruby "$ruby_v" && rvm use "$ruby_v"
