import 'dart:io';
import 'dart:ui' as ui;

import 'package:dbus/dbus.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';
import '../debug/app_talker.dart';

/// A count on the app's icon: the Dock badge on macOS, an overlay on the
/// taskbar button on Windows, and the launcher entry count on Linux (shown
/// by Ubuntu Dock, KDE Plasma and Plank; plain GNOME shows none), which
/// needs the entry `LinuxDesktopEntry` writes.
class AppIconBadge {
  AppIconBadge({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('worknexus/app_icon_badge');

  /// The overlay's side in pixels; Windows draws it at 16 and scales down.
  static const _overlaySize = 32;

  final MethodChannel _channel;
  DBusClient? _dbus;

  /// Shows [count] on the icon, or clears it at 0. [color] and [textColor]
  /// paint the Windows overlay; macOS and Linux draw their own badge.
  Future<void> show(
    int count, {
    required ui.Color color,
    required ui.Color textColor,
  }) async {
    try {
      if (Platform.isMacOS) {
        await _channel.invokeMethod<void>('set', {
          'label': count <= 0 ? '' : _label(count, max: 99),
        });
      } else if (Platform.isWindows) {
        await _channel.invokeMethod<void>(
          'set',
          count <= 0
              ? null
              : {
                  'rgba': await _overlay(
                    _label(count, max: 9),
                    color,
                    textColor,
                  ),
                  'size': _overlaySize,
                },
        );
      } else if (Platform.isLinux) {
        await (_dbus ??= DBusClient.session()).emitSignal(
          path: DBusObjectPath('/com/worknexus/workNexus'),
          interface: 'com.canonical.Unity.LauncherEntry',
          name: 'Update',
          values: [
            const DBusString('application://${AppConfig.linuxAppId}.desktop'),
            DBusDict.stringVariant({
              'count': DBusInt64(count),
              'count-visible': DBusBoolean(count > 0),
            }),
          ],
        );
      }
    } on Object catch (error, stackTrace) {
      // No badge is a cosmetic loss: a dock or bus that refuses it must not
      // break the app.
      appTalker.handle(error, stackTrace, 'App badge: update failed');
    }
  }

  static String _label(int count, {required int max}) =>
      count > max ? '$max+' : '$count';

  /// A filled circle holding [label], as straight RGBA rows.
  static Future<Uint8List> _overlay(
    String label,
    ui.Color color,
    ui.Color textColor,
  ) async {
    const side = _overlaySize;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)
      ..drawCircle(
        const ui.Offset(side / 2, side / 2),
        side / 2,
        ui.Paint()..color = color,
      );
    final builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              textAlign: ui.TextAlign.center,
              fontWeight: ui.FontWeight.w700,
              // Two characters ("9+") need a smaller face to fit the circle.
              fontSize: side * (label.length > 1 ? 0.5 : 0.65),
              height: 1,
            ),
          )
          ..pushStyle(ui.TextStyle(color: textColor))
          ..addText(label);
    final paragraph = builder.build()
      ..layout(const ui.ParagraphConstraints(width: side * 1.0));
    canvas.drawParagraph(
      paragraph,
      ui.Offset(0, (side - paragraph.height) / 2),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(side, side);
    try {
      final data = await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      if (data == null) throw StateError('The badge could not be drawn');
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      image.dispose();
      picture.dispose();
      paragraph.dispose();
    }
  }
}
