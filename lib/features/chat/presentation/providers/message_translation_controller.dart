import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/error/result.dart';
import '../../../../core/settings/app_settings.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_message_translation.dart';
import '../../domain/repositories/message_translation_repository.dart';
import '../../domain/usecases/translate_chat_message.dart';
import '../../domain/value_objects/message_content.dart';

/// A translation that is being made or has failed. A finished one lives in the
/// database ([messageTranslationProvider]), so it survives a restart.
class MessageTranslation {
  const MessageTranslation({this.loading = false, this.error});

  final bool loading;
  final String? error;
}

/// The stored translation of a message into the language chosen in Settings;
/// [ChatMessageTranslation.visible] says whether it is shown.
final messageTranslationProvider = StreamProvider.autoDispose
    .family<ChatMessageTranslation?, ({String accountId, String gid})>((
      ref,
      message,
    ) {
      final lang = ref.watch(
        appSettingsProvider.select((s) => s.translationLang),
      );
      return getIt<MessageTranslationRepository>().watch(
        message.accountId,
        message.gid,
        lang,
      );
    });

/// Translations in flight or failed, by message gid.
class MessageTranslationController
    extends Notifier<Map<String, MessageTranslation>> {
  @override
  Map<String, MessageTranslation> build() => const {};

  /// Translates [message], showing it as in progress at once. [ready]
  /// (e.g. checking a translator is set up, which can take a moment) runs
  /// after that; false stops without a translation.
  Future<void> translate(
    ChatMessage message, {
    Future<bool> Function()? ready,
  }) async {
    if (message.content is! TextContent ||
        state[message.gid]?.loading == true) {
      return;
    }
    _set(message.gid, const MessageTranslation(loading: true));
    if (ready != null && !await ready()) {
      _clear(message.gid);
      return;
    }
    final settings = ref.read(appSettingsProvider);
    final result = await getIt<TranslateChatMessage>()(
      message,
      targetLang: settings.translationLang,
      model: settings.translationModel.isEmpty
          ? null
          : settings.translationModel,
    );
    switch (result) {
      // The stored translation takes over from here.
      case Ok():
        _clear(message.gid);
      case Err(:final failure):
        _set(message.gid, MessageTranslation(error: failure.message));
    }
  }

  /// Hides the translation (it stays stored) or clears a failure.
  Future<void> hide(ChatMessage message) async {
    _clear(message.gid);
    await getIt<MessageTranslationRepository>().setVisible(
      message.accountId,
      message.gid,
      ref.read(appSettingsProvider).translationLang,
      visible: false,
    );
  }

  void _set(String gid, MessageTranslation value) =>
      state = {...state, gid: value};

  void _clear(String gid) => state = {...state}..remove(gid);
}

final messageTranslationControllerProvider =
    NotifierProvider<
      MessageTranslationController,
      Map<String, MessageTranslation>
    >(MessageTranslationController.new);
