#!/usr/bin/env bash

set -euo pipefail
shopt -s nullglob

read -ra REBUILD <<< "$REBUILD"
sudo sed -i "s|^#CacheDir .*|CacheDir = $RUNNER_TEMP/pkgs|" /etc/pacman.conf

cat << EOF > "$HOME/.makepkg.conf"
PACKAGER="Pascal Diehm <pdiehm8@gmail.com>"
GPGKEY="2E0A8522A1B73901C93EF024DF9F6915A409F6E8"

PKGEXT=".pkg.tar.zst"
BUILDENV=(!distcc !color !ccache check sign)
OPTIONS=(strip docs !libtool !staticlibs emptydirs zipman purge !debug lto)

SRCDEST="$RUNNER_TEMP/src"
PKGDEST="$RUNNER_TEMP/pkgs"
BUILDDIR="$RUNNER_TEMP/build"
EOF

if [[ $GPG_KEY ]]; then
  sudo pacman-key --init
  gpg --import <<< "$GPG_KEY"
  gpg --export "2E0A8522A1B73901C93EF024DF9F6915A409F6E8" | sudo pacman-key --add -
  sudo pacman-key --lsign-key "2E0A8522A1B73901C93EF024DF9F6915A409F6E8"
else
  sed -i "s/sign/!sign/" "$HOME/.makepkg.conf"
  sudo sed -i "s/^LocalFileSigLevel .*/LocalFileSigLevel = Never/" /etc/pacman.conf
fi

declare -A DEPS BUILT
mkdir "$RUNNER_TEMP/repo"

build() {
  local pkg="$1" deps dep start time
  if [[ -v BUILT[$pkg] ]]; then return; fi
  BUILT[$pkg]=1

  if [[ -v DEPS[$pkg] ]]; then
    read -ra deps <<< "${DEPS[$pkg]}"
    for dep in "${deps[@]}"; do build "$dep"; done
  fi

  echo "::group::$pkg"
  start="$(date +%s)"
  if [[ -f $pkg.patch ]]; then patch -d "$pkg" -p 1 < "$pkg.patch"; fi

  case "$pkg" in
    paru) makepkg --noconfirm --syncdeps --install --dir "$pkg" ;;
    *) paru --noconfirm --build --install "$pkg" ;;
  esac

  echo "::endgroup::"
  time="$(($(date +%s) - start))"
  printf "| %s | %dm %02ds |\n" "$pkg" "$((time / 60))" "$((time % 60))" >> "$GITHUB_STEP_SUMMARY"

  makepkg --packagelist --dir "$pkg" | while read -r pkg; do
    if [[ -f $pkg ]]; then cp "$pkg" "$RUNNER_TEMP/repo"; fi
    if [[ -f $pkg.sig ]]; then cp "$pkg.sig" "$RUNNER_TEMP/repo"; fi
  done
}

for pkg in "${REBUILD[@]}"; do
  makepkg --packagelist --dir "$pkg" | while read -r pkg; do
    rm -f "$pkg" "$pkg.sig"
  done
done

cat << EOF >> "$GITHUB_STEP_SUMMARY"
## Build Times
| Package | Duration |
| ------- | -------- |
EOF

while read -r pkg deps; do DEPS[$pkg]="$deps"; done < deps.txt
for pkg in paru */; do build "${pkg%/}"; done

if [[ $GPG_KEY ]]; then
  repo-add --include-sigs --sign --key "2E0A8522A1B73901C93EF024DF9F6915A409F6E8" "$RUNNER_TEMP/repo/aur.db.tar.gz" "$RUNNER_TEMP/repo"/*.pkg.tar.zst
  rmdir "$RUNNER_TEMP/pkgs"/download-* # HACK: https://gitlab.archlinux.org/pacman/pacman/-/work_items/297
  sudo pacman --noconfirm --sync --clean
fi

cat << EOF >> "$GITHUB_STEP_SUMMARY"
## Package Repo
| Package | Size |
| ------- | ---- |
$(du -bh "$RUNNER_TEMP/repo"/*.pkg.tar.zst | while read -r size pkg; do echo "| ${pkg##*/} | $size |"; done)

## Debug Info
<details>
<summary>Package Cache</summary>
<pre>$(ls -lh "$RUNNER_TEMP/pkgs")</pre>
</details>
EOF
