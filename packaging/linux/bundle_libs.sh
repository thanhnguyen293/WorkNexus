#!/usr/bin/env bash
# Copies the tray plugin's native libraries into the release bundle, so the app
# starts on a distro that lacks them: tray_manager links ayatana-appindicator,
# which few distros besides Ubuntu install by default (the loader refuses to
# start the app without it). GTK, GLib, libsecret and WebKitGTK (mini apps)
# stay with the system: every desktop has them, a bundled GTK would clash with
# the system's, and the system keeps WebKitGTK patched.
#   packaging/linux/bundle_libs.sh <bundle dir>
#
# The bundled libraries and the plugin get a RUNPATH of $ORIGIN: the binary's
# own $ORIGIN/lib only covers its direct dependencies, not the plugin's.
# fvp's libmdk / libffmpeg get the same: fvp downloads them from mdk-sdk's
# nightly channel, and a nightly shipped libmdk with a RUNPATH of "$:$/lib..."
# (no ORIGIN), so it could not find the libc++.so.1 bundled beside it and the
# app failed to start on any system without libc++ installed.
set -euo pipefail

lib="$(cd "$1/lib" && pwd)"
plugin="$lib/libtray_manager_plugin.so"

# ldd lists the whole dependency tree, as resolved on the build host.
mapfile -t libs < <(ldd "$plugin" | awk '/ayatana|dbusmenu/ { print $3 }')
if [ "${#libs[@]}" -eq 0 ]; then
  echo "No ayatana / dbusmenu libraries found for $plugin" >&2
  exit 1
fi

for path in "${libs[@]}"; do
  # -L: the soname is a symlink; copy the library under that name.
  cp -L "$path" "$lib/"
  patchelf --set-rpath '$ORIGIN' "$lib/$(basename "$path")"
done
patchelf --set-rpath '$ORIGIN' "$plugin"

# Every one of them must now resolve inside the bundle.
outside=$(ldd "$plugin" | awk -v lib="$lib/" \
  '/ayatana|dbusmenu/ && index($3, lib) != 1 { print $1 " => " $3 }')
if [ -n "$outside" ]; then
  echo "Still resolved outside the bundle:" >&2
  echo "$outside" >&2
  exit 1
fi
printf 'Bundled %s\n' "${libs[@]##*/}"

for mdk in "$lib"/libmdk*.so* "$lib"/libffmpeg.so*; do
  [ -e "$mdk" ] && patchelf --set-rpath '$ORIGIN' "$mdk"
done

# The whole app, not just the tray plugin: anything the bundle ships must be
# what the loader picks, so a bundled library that a system copy (or nothing)
# shadows fails here rather than on a user's machine.
outside=$(ldd "$1/WorkNexus" | while read -r name arrow path rest; do
  if [ "$arrow" = "=>" ] && [ -e "$lib/$name" ] && [ "$path" != "$lib/$name" ]; then
    echo "$name => $path $rest"
  fi
done)
if [ -n "$outside" ]; then
  echo "Bundled libraries not resolved inside the bundle:" >&2
  echo "$outside" >&2
  exit 1
fi
