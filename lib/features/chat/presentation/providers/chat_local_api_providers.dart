import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../core/debug/app_talker.dart';
import '../../../../core/error/result.dart';
import '../../../../core/settings/app_settings.dart';
import '../../domain/repositories/chat_local_api.dart';
import '../../domain/usecases/send_text_message.dart';
import 'chat_providers.dart';

final chatLocalApiProvider = Provider<ChatLocalApi>(
  (ref) => getIt<ChatLocalApi>(),
);

/// Runs the local chat API while its setting is on: started when the user
/// turns it on (or at launch when it was left on), stopped when they turn it
/// off. Messages go through [SendTextMessage], as if typed in the composer.
final chatLocalApiRunnerProvider = Provider<void>((ref) {
  final api = ref.watch(chatLocalApiProvider);
  final send = SendTextMessage(ref.watch(chatRepositoryProvider));

  Future<void> apply(bool on) async {
    final result = on ? await api.start(send.call) : await api.stop();
    if (result case Err(:final failure)) {
      appTalker.error('Local chat API: ${failure.message}', failure.cause);
    }
  }

  ref.listen<bool>(
    appSettingsProvider.select((s) => s.chatLocalApi),
    (_, on) => unawaited(apply(on)),
    fireImmediately: true,
  );
  ref.onDispose(() => unawaited(api.stop()));
});
