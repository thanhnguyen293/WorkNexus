#!/usr/bin/env bash
# Packages the Flutter Linux release bundle as a .deb.
#   packaging/linux/build_deb.sh <version> <bundle dir> <output .deb>
#
# The bundle goes to /opt/worknexus with a `worknexus` launcher on PATH, a
# menu entry and an icon. The entry's file name and StartupWMClass match
# AppConfig.linuxAppId, so docks pair the window with it.
set -euo pipefail

version="$1"
bundle="$2"
output="$3"

app_id="com.worknexus.workNexus"
root="$(mktemp -d)"
trap 'rm -rf "$root"' EXIT

mkdir -p "$root/DEBIAN" "$root/opt/worknexus" "$root/usr/bin" \
  "$root/usr/share/applications" "$root/usr/share/icons/hicolor/256x256/apps"

cp -a "$bundle/." "$root/opt/worknexus/"
ln -s /opt/worknexus/WorkNexus "$root/usr/bin/worknexus"
cp "$(dirname "$0")/../../linux/runner/resources/app_icon.png" \
  "$root/usr/share/icons/hicolor/256x256/apps/$app_id.png"

cat > "$root/usr/share/applications/$app_id.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=WorkNexus
Exec=/opt/worknexus/WorkNexus
Icon=$app_id
Terminal=false
Categories=Office;
StartupWMClass=$app_id
EOF

# Runtime libraries the plugins link (see the build dependencies in CI):
# GTK, libsecret (flutter_secure_storage), ayatana-appindicator (tray_manager).
cat > "$root/DEBIAN/control" <<EOF
Package: worknexus
Version: $version
Section: utils
Priority: optional
Architecture: amd64
Maintainer: WorkNexus
Depends: libgtk-3-0, libsecret-1-0, libayatana-appindicator3-1
Installed-Size: $(du -sk "$root/opt" | cut -f1)
Description: WorkNexus desktop app
EOF

dpkg-deb --build --root-owner-group "$root" "$output"
