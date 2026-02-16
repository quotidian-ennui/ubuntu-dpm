#!/usr/bin/env bash
set -eo pipefail

if ! gh auth status >/dev/null 2>&1; then
  gh auth login -h github.com
fi
gh extension install quotidian-ennui/gh-my || true
gh extension install quotidian-ennui/gh-rate-limit || true
gh extension install quotidian-ennui/gh-squash-merge || true
gh extension install quotidian-ennui/gh-approve-deploy || true
gh extension install quotidian-ennui/gh-merge-train || true
