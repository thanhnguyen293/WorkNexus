import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/chat/domain/repositories/chat_ai_text_generator.dart';
import 'package:work_nexus/features/chat/domain/usecases/rewrite_chat_draft.dart';
import 'package:work_nexus/features/chat/domain/usecases/should_offer_chat_summary.dart';
import 'package:work_nexus/features/chat/domain/value_objects/chat_draft_tone.dart';

import 'chat_ai_test_support.dart';

void main() {
  late MockChatAiTextGenerator ai;
  late RewriteChatDraft rewrite;

  setUp(() {
    ai = MockChatAiTextGenerator();
    rewrite = RewriteChatDraft(ai);
  });

  void answer(String text) => when(
    () => ai.generate(
      key: any(named: 'key'),
      prompt: any(named: 'prompt'),
      model: any(named: 'model'),
    ),
  ).thenAnswer((_) async => Ok(ChatAiReply(text)));

  String prompt() =>
      verify(
            () => ai.generate(
              key: any(named: 'key'),
              prompt: captureAny(named: 'prompt'),
              model: any(named: 'model'),
            ),
          ).captured.single
          as String;

  test('asks for the tone, quoting the draft and the context', () async {
    answer('Could you review it today, please?');
    final result = await rewrite(
      'review it today',
      tone: ChatDraftTone.formal,
      key: 'k',
      context: [chatText('I pushed the fix')],
      selfName: 'An',
      nameOf: chatName,
    );

    expect(result.valueOrNull, 'Could you review it today, please?');
    final asked = prompt();
    expect(asked, contains('polite, professional tone'));
    expect(asked, contains('review it today'));
    expect(asked, contains('Lan: I pushed the fix'));
  });

  test('takes the quotes and code fence off the answer', () async {
    answer('```\n"Shorter."\n```');
    final result = await rewrite(
      'a much longer draft',
      tone: ChatDraftTone.shorter,
      key: 'k',
    );
    expect(result.valueOrNull, 'Shorter.');
    expect(prompt(), isNot(contains('context only')));
  });

  test('a blank draft is refused without asking', () async {
    final result = await rewrite('  ', tone: ChatDraftTone.clearer, key: 'k');
    expect(result.isErr, isTrue);
    verifyNever(
      () => ai.generate(
        key: any(named: 'key'),
        prompt: any(named: 'prompt'),
        model: any(named: 'model'),
      ),
    );
  });

  group('ShouldOfferChatSummary', () {
    test('offers from the threshold up', () {
      const offer = ShouldOfferChatSummary();
      expect(offer(unread: 19), isFalse);
      expect(offer(unread: 20), isTrue);
      expect(const ShouldOfferChatSummary(threshold: 5)(unread: 5), isTrue);
    });
  });
}
