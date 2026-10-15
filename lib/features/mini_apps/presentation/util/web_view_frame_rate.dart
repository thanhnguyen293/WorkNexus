import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Caps how often the Windows web view behind [web] hands Flutter a new frame;
/// 0 lifts the cap. Each frame it hands over makes Flutter draw a frame of
/// its own, even for a page that is not on screen, so a hidden page that
/// keeps running is held to a few.
///
/// flutter_inappwebview (windows 0.6.0) has this on the view's own channel
/// but no public call for it: the channel is named after the texture, whose
/// id is the view id. A missing channel (another version) is ignored.
Future<void> setWebViewFrameRateLimit(
  InAppWebViewController web,
  int fps,
) async {
  final id = web.getViewId();
  if (id is! int) return;
  try {
    await MethodChannel(
      'com.pichillilorenzo/custom_platform_view_$id',
    ).invokeMethod<void>('setFpsLimit', fps);
  } on MissingPluginException {
    // Not this plugin version's channel: frames stay unlimited.
  } on PlatformException {
    // The view went away meanwhile.
  }
}
