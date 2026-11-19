import 'dart:async';
import 'package:flutter/services.dart';

/// The native side of the panic switch (`worknexus/panic_switch`, set up in
/// each platform's runner): app listing/activation and the floating button.
class PanicSwitchChannel {
  PanicSwitchChannel({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('worknexus/panic_switch') {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'overlayTriggered') {
        // Older runners sent no argument: the left-button trigger.
        _triggers.add(call.arguments as String? ?? 'release');
      }
    });
  }

  final MethodChannel _channel;
  final _triggers = StreamController<String>.broadcast();

  /// Triple clicks on the floating button: `release` (left button) or `demo`
  /// (right button).
  Stream<String> get triggers => _triggers.stream;

  Future<List<({String id, String name})>> listApps() async {
    final apps = await _channel.invokeListMethod<Map<Object?, Object?>>(
      'listApps',
    );
    return [
      for (final app in apps ?? const <Map<Object?, Object?>>[])
        if (app case {'id': final String id, 'name': final String name})
          (id: id, name: name),
    ];
  }

  Future<void> activate(String id) =>
      _channel.invokeMethod<void>('activate', {'id': id});

  Future<void> hideOthers(List<String> keep) =>
      _channel.invokeMethod<void>('hideOthers', {'keep': keep});

  Future<void> hideSelf() => _channel.invokeMethod<void>('hideSelf');

  Future<void> showOverlay(Uint8List image) =>
      _channel.invokeMethod<void>('showOverlay', {'image': image});

  Future<void> hideOverlay() => _channel.invokeMethod<void>('hideOverlay');
}
