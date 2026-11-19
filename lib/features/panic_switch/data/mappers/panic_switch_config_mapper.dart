import 'dart:convert';

import '../../domain/entities/app_ref.dart';
import '../../domain/entities/panic_switch_config.dart';
import '../../domain/panic_switch_constants.dart';

/// [PanicSwitchConfig] ↔ the JSON it is stored as. Unknown or missing fields
/// fall back to the defaults, so older saved settings still load.
abstract final class PanicSwitchConfigMapper {
  static String toJson(PanicSwitchConfig c) => jsonEncode({
    'enabled': c.enabled,
    'overlayVisible': c.overlayVisible,
    'chatGid': c.chatGid,
    'testMode': c.testMode,
    'testSendChatGid': c.testSendChatGid,
    'testSendToSelf': c.testSendToSelf,
    'testReceiveChatGid': c.testReceiveChatGid,
    'anySender': c.anySender,
    'allowedSenderIds': c.allowedSenderIds,
    'targetApp': c.targetApp == null ? null : _app(c.targetApp!),
    'appsToHide': [for (final a in c.appsToHide) _app(a)],
    'hideSelf': c.hideSelf,
    'debounceSeconds': c.debounceSeconds,
  });

  static PanicSwitchConfig fromJson(String source) {
    final json = jsonDecode(source);
    if (json is! Map<String, dynamic>) return const PanicSwitchConfig();
    // Before test mode, "send to myself" was saved as the one chat
    // (`chatIsSelf`); it is test mode's send chat now, and the team group is
    // looked up again.
    final legacySelf = json['chatIsSelf'] == true;
    final legacySelfGid = legacySelf ? json['chatGid'] as String? : null;
    return PanicSwitchConfig(
      enabled: json['enabled'] as bool? ?? true,
      overlayVisible: json['overlayVisible'] as bool? ?? true,
      chatGid: legacySelf ? null : json['chatGid'] as String?,
      testMode: json['testMode'] as bool? ?? legacySelf,
      testSendChatGid: json['testSendChatGid'] as String? ?? legacySelfGid,
      testSendToSelf: json['testSendToSelf'] as bool? ?? legacySelf,
      testReceiveChatGid: json['testReceiveChatGid'] as String?,
      anySender: json['anySender'] as bool? ?? true,
      allowedSenderIds: [
        for (final id in json['allowedSenderIds'] as List? ?? const [])
          if (id is int) id,
      ],
      targetApp: _readApp(json['targetApp']),
      appsToHide: [
        for (final a in json['appsToHide'] as List? ?? const []) ?_readApp(a),
      ],
      hideSelf: json['hideSelf'] as bool? ?? true,
      debounceSeconds:
          json['debounceSeconds'] as int? ??
          PanicSwitchConstants.defaultDebounceSeconds,
    );
  }

  static Map<String, String> _app(AppRef a) => {'id': a.id, 'name': a.name};

  static AppRef? _readApp(Object? json) => switch (json) {
    {'id': final String id, 'name': final String name} => AppRef(
      id: id,
      name: name,
    ),
    _ => null,
  };
}
