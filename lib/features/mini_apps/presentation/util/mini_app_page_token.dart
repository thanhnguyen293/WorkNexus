import 'dart:math';

/// A secret only a page's main-frame script knows: the web view's JavaScript
/// bridge is open to every frame, and a call that does not start with the
/// token (a cross-origin iframe cannot read it) is ignored.
String newMiniAppPageToken() {
  final random = Random.secure();
  return [
    for (var i = 0; i < 16; i++)
      random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();
}
