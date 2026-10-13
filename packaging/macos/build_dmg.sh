#!/usr/bin/env bash
# Packages the macOS .app as a drag-to-Applications disk image.
#   packaging/macos/build_dmg.sh <path to WorkNexus.app> <output .dmg>
set -euo pipefail

app="$1"
output="$2"

stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT

# ditto keeps the bundle's symlinks, permissions and signature intact.
ditto "$app" "$stage/$(basename "$app")"
ln -s /Applications "$stage/Applications"

hdiutil create -volname WorkNexus -srcfolder "$stage" -fs HFS+ \
  -format UDZO -ov "$output"
