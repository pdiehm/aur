#!/usr/bin/env bash

set -euo pipefail
PKG="$1"

trap 'git submodule deinit --force "$PKG"' EXIT
git submodule update --init "$PKG"

if [[ -f $PKG.patch ]]; then
  patch -d "$PKG" -p 1 < "$PKG.patch"
  git -C "$PKG" add .
fi

env -C "$PKG" "$EDITOR" .
git -C "$PKG" diff --staged > "$PKG.patch"
if [[ ! -s $PKG.patch ]]; then rm "$PKG.patch"; fi
