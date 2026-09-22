#!/usr/bin/env bash

set -euo pipefail
PKG="$1"

trap 'git submodule deinit --force "$PKG"' EXIT
git submodule update --init "$PKG"

if [[ -f $PKG.patch ]]; then
  if patch -d "$PKG" -p 1 < "$PKG.patch"; then
    git -C "$PKG" add .
  fi
fi

env -C "$PKG" "$EDITOR" .
git -C "$PKG" diff --staged > "$PKG.patch"
if [[ ! -s $PKG.patch ]]; then rm "$PKG.patch"; fi
