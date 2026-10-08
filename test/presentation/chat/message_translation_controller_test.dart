import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_message.dart';
import 'package:work_nexus/features/chat/domain/value_objects/message_content.dart';
import 'package:work_nexus/features/chat/presentation/providers/message_translation_controller.dart';

void main() {
  final message = ChatMessage(
    accountId: 'acc',
    gid: 'm1',
    chatGid: 'g1',
    senderId: 1,
    sentAt: DateTime(2026),
    content: const MessageContent.text('xin chào'),
    isMine: false,
  );

  test('shows the translation in progress before the slow check', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final translations = container.read(
      messageTranslationControllerProvider.notifier,
    );
    bool? loadingWhileChecking;

    await translations.translate(
      message,
      ready: () async {
        loadingWhileChecking = container
            .read(messageTranslationControllerProvider)['m1']
            ?.loading;
        return false;
      },
    );

    expect(loadingWhileChecking, isTrue);
    // Not ready (no translator linked): nothing is left in progress.
    expect(container.read(messageTranslationControllerProvider), isEmpty);
  });
}
