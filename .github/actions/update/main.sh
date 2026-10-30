#!/usr/bin/env bash

set -euo pipefail

PKGS=(*/.nvchecker.toml)
pkgctl version upgrade "${PKGS[@]%/*}"
git add ./*/PKGBUILD

if ! git diff --staged --quiet; then
  git config user.name "github-actions[bot]"
  git config user.email "github-actions[bot]@users.noreply.github.com"
  git commit --message "chore: update package versions"
fi
