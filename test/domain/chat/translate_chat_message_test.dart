import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_message.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_message_translation.dart';
import 'package:work_nexus/features/chat/domain/repositories/message_translation_repository.dart';
import 'package:work_nexus/features/chat/domain/usecases/translate_chat_message.dart';
import 'package:work_nexus/features/chat/domain/value_objects/message_content.dart';
import 'package:work_nexus/features/translation/domain/adapters/translation_service.dart';

class _MockRepo extends Mock implements MessageTranslationRepository {}

class _MockService extends Mock implements TranslationService {}

void main() {
  final message = ChatMessage(
    accountId: 'a',
    gid: 'g1',
    chatGid: 'c',
    senderId: 1,
    sentAt: DateTime(2026),
    content: const TextContent('hi [@Bob](@#7)'),
    isMine: false,
  );
  final stored = ChatMessageTranslation(
    accountId: 'a',
    gid: 'g1',
    targetLang: 'vi',
    text: 'chào',
    createdAt: DateTime(2026),
  );

  late _MockRepo repo;
  late _MockService service;
  late TranslateChatMessage translate;

  setUpAll(() => registerFallbackValue(stored));
  setUp(() {
    repo = _MockRepo();
    service = _MockService();
    translate = TranslateChatMessage(repo, service);
    when(() => repo.save(any())).thenAnswer((_) async => const Ok(null));
  });

  test('returns the stored translation without calling the model', () async {
    when(() => repo.find('a', 'g1', 'vi')).thenAnswer((_) async => Ok(stored));
    final result = await translate(message, targetLang: 'vi');
    expect((result as Ok<ChatMessageTranslation>).value, stored);
    verifyNever(
      () => service.translateText(
        key: any(named: 'key'),
        text: any(named: 'text'),
        targetLang: any(named: 'targetLang'),
        model: any(named: 'model'),
      ),
    );
  });

  test('showing a hidden stored translation marks it visible again', () async {
    final hidden = stored.copyWith(visible: false);
    when(() => repo.find('a', 'g1', 'vi')).thenAnswer((_) async => Ok(hidden));
    when(
      () => repo.setVisible('a', 'g1', 'vi', visible: true),
    ).thenAnswer((_) async => const Ok(null));
    final result = await translate(message, targetLang: 'vi');
    expect((result as Ok<ChatMessageTranslation>).value.visible, isTrue);
    verify(() => repo.setVisible('a', 'g1', 'vi', visible: true)).called(1);
  });

  test('translates, strips mentions and stores the result', () async {
    when(
      () => repo.find('a', 'g1', 'vi'),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => service.translateText(
        key: any(named: 'key'),
        text: 'hi @Bob',
        targetLang: 'vi',
        model: 'm',
      ),
    ).thenAnswer(
      (_) async => const Ok(TextTranslation('chào @Bob', model: 'gemini-x')),
    );
    final result = await translate(message, targetLang: 'vi', model: 'm');
    final value = (result as Ok<ChatMessageTranslation>).value;
    expect(value.text, 'chào @Bob');
    // The label names the model that answered, not the one asked for.
    expect(value.model, 'gemini-x');
    verify(() => repo.save(any())).called(1);
  });

  test('force translates again over a stored translation', () async {
    when(() => repo.find('a', 'g1', 'vi')).thenAnswer((_) async => Ok(stored));
    when(
      () => service.translateText(
        key: any(named: 'key'),
        text: any(named: 'text'),
        targetLang: 'vi',
        model: any(named: 'model'),
      ),
    ).thenAnswer((_) async => const Ok(TextTranslation('xin chào')));
    final result = await translate(message, targetLang: 'vi', force: true);
    final value = (result as Ok<ChatMessageTranslation>).value;
    expect(value.text, 'xin chào');
    expect(value.visible, isTrue);
    verifyNever(() => repo.find(any(), any(), any()));
    verify(() => repo.save(any())).called(1);
  });

  test('a failed translation is not stored', () async {
    when(
      () => repo.find('a', 'g1', 'vi'),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => service.translateText(
        key: any(named: 'key'),
        text: any(named: 'text'),
        targetLang: any(named: 'targetLang'),
        model: any(named: 'model'),
      ),
    ).thenAnswer((_) async => const Err(AgentFailure('boom')));
    expect(
      await translate(message, targetLang: 'vi'),
      isA<Err<ChatMessageTranslation>>(),
    );
    verifyNever(() => repo.save(any()));
  });
}
