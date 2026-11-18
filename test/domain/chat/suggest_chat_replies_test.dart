import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/chat/domain/repositories/chat_ai_text_generator.dart';
import 'package:work_nexus/features/chat/domain/usecases/suggest_chat_replies.dart';

import 'chat_ai_test_support.dart';

void main() {
  late MockChatAiTextGenerator ai;
  late SuggestChatReplies suggest;

  setUp(() {
    ai = MockChatAiTextGenerator();
    suggest = SuggestChatReplies(ai);
  });

  void answer(String text) => when(
    () => ai.generate(
      key: any(named: 'key'),
      prompt: any(named: 'prompt'),
      model: any(named: 'model'),
    ),
  ).thenAnswer((_) async => Ok(ChatAiReply(text)));

  Future<Result<List<String>>> run() => suggest(
    [chatText('Can you review my MR today?')],
    key: 'k',
    selfName: 'An',
    nameOf: chatName,
  );

  test('asks for replies on behalf of the user', () async {
    answer('["Sure"]');
    await run();
    final prompt =
        verify(
              () => ai.generate(
                key: 'k',
                prompt: captureAny(named: 'prompt'),
              ),
            ).captured.single
            as String;
    expect(prompt, contains('replies An could send'));
    expect(prompt, contains('Lan: Can you review my MR today?'));
  });

  test('reads the JSON list, keeping at most three', () async {
    answer('Here: ["Sure, after lunch", "Which MR?", "Done", "Later"]');
    expect((await run()).valueOrNull, [
      'Sure, after lunch',
      'Which MR?',
      'Done',
    ]);
  });

  test('falls back to one reply a line without numbering', () async {
    answer('1. "Sure"\n- Which MR?\n\n• Tomorrow works');
    expect((await run()).valueOrNull, ['Sure', 'Which MR?', 'Tomorrow works']);
  });

  test('no replies is a failure', () async {
    answer('[]');
    expect((await run()).isErr, isTrue);
  });
}
