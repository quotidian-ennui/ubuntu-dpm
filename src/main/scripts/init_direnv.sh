#!/usr/bin/env bash

set -eo pipefail
mkdir -p ~/.config/direnv && wget -q -O ~/.config/direnv/direnvrc https://raw.githubusercontent.com/direnv/direnv/master/stdlib.sh
mkdir -p ~/.local/share/direnv/allow
