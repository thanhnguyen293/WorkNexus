#!/usr/bin/env bash
# Packages the Flutter Linux release bundle as an AppImage: one file that runs
# on most distros without installing anything (the bundle already carries the
# tray libraries, see bundle_libs.sh).
#   packaging/linux/build_appimage.sh <version> <bundle dir> <output .AppImage>
#
# The desktop file and icon are named after AppConfig.linuxAppId, so docks
# pair the window with them.
set -euo pipefail

version="$1"
bundle="$2"
output="$(realpath -m "$3")"

app_id="com.worknexus.workNexus"
# Pinned: appimagetool fetches the static type2 runtime, so the image needs no
# libfuse2 on the user's machine.
tool_url="https://github.com/AppImage/appimagetool/releases/download/1.9.1/appimagetool-x86_64.AppImage"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
appdir="$work/WorkNexus.AppDir"
mkdir -p "$appdir/worknexus"

cp -a "$bundle/." "$appdir/worknexus/"
cp "$(dirname "$0")/../../linux/runner/resources/app_icon.png" "$appdir/$app_id.png"
ln -s "$app_id.png" "$appdir/.DirIcon"

cat > "$appdir/AppRun" <<'EOF'
#!/bin/sh
here="$(dirname "$(readlink -f "$0")")"
exec "$here/worknexus/WorkNexus" "$@"
EOF
chmod +x "$appdir/AppRun"

cat > "$appdir/$app_id.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=WorkNexus
Exec=WorkNexus
Icon=$app_id
Terminal=false
Categories=Office;
StartupWMClass=$app_id
EOF

curl -fsSL -o "$work/appimagetool" "$tool_url"
chmod +x "$work/appimagetool"
# EXTRACT_AND_RUN: the CI runner has no FUSE to mount the tool itself.
ARCH=x86_64 VERSION="$version" APPIMAGE_EXTRACT_AND_RUN=1 \
  "$work/appimagetool" --no-appstream "$appdir" "$output"
