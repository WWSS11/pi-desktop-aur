#!/usr/bin/env bash
# Assert the on-disk layout a user gets after installing pi-desktop-bin.
#
# This is the "test suite" of this packaging repository: it turns an upstream
# refactor that renames the electron-builder output directory, drops a bundled
# resource, or changes how the launcher is installed into a hard failure.
#
# Usage: scripts/verify-package.sh <pi-desktop-bin-*.pkg.tar.zst>
#
# Called by:
#   .github/workflows/build.yml  — on the freshly built package, before publishing
#   .github/workflows/verify.yml — on the package served from the public repo URL
set -euo pipefail

pkg="${1:-}"
if [[ -z "$pkg" || ! -f "$pkg" ]]; then
  echo "usage: $0 <pi-desktop-bin-*.pkg.tar.zst>" >&2
  exit 2
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

echo "== extracting ${pkg} =="
bsdtar -xf "$pkg" -C "$work"

echo "== /opt/PI-Desktop =="
ls -la "$work/opt/PI-Desktop"
echo "== /opt/PI-Desktop/resources =="
ls -la "$work/opt/PI-Desktop/resources"
echo "== desktop entry and icons =="
ls -la "$work/usr/share/applications" \
       "$work/usr/share/icons/hicolor/512x512/apps" \
       "$work/usr/share/icons/hicolor/1024x1024/apps"

status=0
require() {
  # `-e` alone follows symlinks, so `usr/bin/pi-desktop` (an absolute link into
  # /opt that cannot resolve inside this temporary extraction root) would look
  # missing. Accept dangling links as present; the readlink check below is what
  # validates the target.
  if [[ -e "$work/$1" || -L "$work/$1" ]]; then
    echo "ok: $1"
  else
    echo "MISSING: $1" >&2
    status=1
  fi
}

# Electron runtime + app payload produced by electron-vite / electron-builder.
require opt/PI-Desktop/pi-desktop
require opt/PI-Desktop/chrome-sandbox
require opt/PI-Desktop/icudtl.dat
require opt/PI-Desktop/resources/app.asar
# Rust host core, built by `cargo build --release -p host-core`.
require opt/PI-Desktop/resources/bin/pi-desktop-host-core
# Bundled agent runtime sidecar (packages/agent-runtime `bundle:runtime`).
require opt/PI-Desktop/resources/agent-runtime/sidecar.js
# extraResources declared in apps/desktop/package.json.
require opt/PI-Desktop/resources/skills
require opt/PI-Desktop/resources/plugins
require opt/PI-Desktop/resources/models.dev/api.json
require opt/PI-Desktop/resources/tray-icon.png
# Arch packaging added by this repository.
require usr/bin/pi-desktop
require usr/share/applications/pi-desktop.desktop
require usr/share/icons/hicolor/512x512/apps/pi-desktop.png
require usr/share/icons/hicolor/1024x1024/apps/pi-desktop.png
require usr/share/licenses/pi-desktop-git/LICENSE

check() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "ok: ${label} (${actual})"
  else
    echo "FAIL: ${label}: expected '${expected}', got '${actual}'" >&2
    status=1
  fi
}

check "launcher symlink" "/opt/PI-Desktop/pi-desktop" \
  "$(readlink "$work/usr/bin/pi-desktop" 2>/dev/null || echo '<missing>')"
check "app binary is executable" "yes" \
  "$([[ -x "$work/opt/PI-Desktop/pi-desktop" ]] && echo yes || echo no)"
check "chrome-sandbox mode" "4755" \
  "$(stat -c '%a' "$work/opt/PI-Desktop/chrome-sandbox" 2>/dev/null || echo '<missing>')"
check "desktop entry Icon" "Icon=pi-desktop" \
  "$(sed -n 's/^\(Icon=.*\)$/\1/p' "$work/usr/share/applications/pi-desktop.desktop" 2>/dev/null || echo '<missing>')"
check "desktop entry StartupWMClass" "StartupWMClass=pi-desktop" \
  "$(sed -n 's/^\(StartupWMClass=.*\)$/\1/p' "$work/usr/share/applications/pi-desktop.desktop" 2>/dev/null || echo '<missing>')"
check "desktop entry Exec" "Exec=/usr/bin/pi-desktop %U" \
  "$(sed -n 's/^\(Exec=.*\)$/\1/p' "$work/usr/share/applications/pi-desktop.desktop" 2>/dev/null || echo '<missing>')"

# pi-desktop-bin ships no license file of its own: it links to the one inside
# the pi-desktop-git payload, so this also proves the symlink resolves.
if [[ -s "$work/usr/share/licenses/pi-desktop-bin/LICENSE" ]] \
   && grep -qF 'GNU LESSER GENERAL PUBLIC LICENSE' "$work/usr/share/licenses/pi-desktop-bin/LICENSE"; then
  echo "ok: license symlink resolves to the upstream LGPL text"
else
  echo "FAIL: /usr/share/licenses/pi-desktop-bin does not resolve to the upstream LGPL LICENSE" >&2
  status=1
fi

if (( status != 0 )); then
  echo "PACKAGE VERIFICATION FAILED" >&2
  exit 1
fi

echo "PACKAGE VERIFICATION PASSED"
