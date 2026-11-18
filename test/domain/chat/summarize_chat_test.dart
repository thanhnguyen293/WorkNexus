import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_summary.dart';
import 'package:work_nexus/features/chat/domain/repositories/chat_ai_text_generator.dart';
import 'package:work_nexus/features/chat/domain/usecases/summarize_chat.dart';

import 'chat_ai_test_support.dart';

void main() {
  late MockChatAiTextGenerator ai;
  late SummarizeChat summarize;

  setUp(() {
    ai = MockChatAiTextGenerator();
    summarize = SummarizeChat(ai);
  });

  void answer(String text, {String? model}) => when(
    () => ai.generate(
      key: any(named: 'key'),
      prompt: any(named: 'prompt'),
      model: any(named: 'model'),
    ),
  ).thenAnswer((_) async => Ok(ChatAiReply(text, model: model)));

  Future<Result<ChatSummary>> run() => summarize(
    [chatText('ship it on Friday?'), chatText('yes', minute: 1, sender: 3)],
    key: 'k',
    languageName: 'Vietnamese',
    selfName: 'An',
    nameOf: chatName,
    model: 'm',
  );

  test('asks in the language given, quoting the conversation', () async {
    answer('{"overview": "ok"}');
    await run();
    final prompt =
        verify(
              () => ai.generate(
                key: 'k',
                prompt: captureAny(named: 'prompt'),
                model: 'm',
              ),
            ).captured.single
            as String;
    expect(prompt, contains('Write in Vietnamese'));
    expect(prompt, contains('Lan: ship it on Friday?'));
    expect(prompt, contains('2 messages'));
  });

  test('reads every section of the JSON answer', () async {
    answer('''Sure! ```json
{"overview": "Release planning.",
 "keyPoints": ["Friday release", " "],
 "decisions": ["Ship on Friday"],
 "actionItems": [{"owner": "Minh", "task": "Tag the build", "due": "Fri"},
                 {"owner": "x"}],
 "openQuestions": ["Who writes the notes?"]}
```''', model: 'gemini');
    final summary = (await run()).valueOrNull!;

    expect(summary.overview, 'Release planning.');
    expect(summary.keyPoints, ['Friday release']);
    expect(summary.decisions, ['Ship on Friday']);
    expect(summary.actionItems, [
      const ChatActionItem(task: 'Tag the build', owner: 'Minh', due: 'Fri'),
    ]);
    expect(summary.openQuestions, ['Who writes the notes?']);
    expect(summary.messageCount, 2);
    expect(summary.model, 'gemini');
  });

  test('an answer that is not JSON becomes the overview', () async {
    answer('  They agreed to ship on Friday.  ');
    final summary = (await run()).valueOrNull!;
    expect(summary.overview, 'They agreed to ship on Friday.');
    expect(summary.keyPoints, isEmpty);
  });

  test('passes a failure through', () async {
    when(
      () => ai.generate(
        key: any(named: 'key'),
        prompt: any(named: 'prompt'),
        model: any(named: 'model'),
      ),
    ).thenAnswer((_) async => const Err(AuthFailure('bad key')));
    expect((await run()).failureOrNull, isA<AuthFailure>());
  });

  test('does not call the model without messages', () async {
    final result = await summarize(
      [chatText('gone', deleted: true)],
      key: 'k',
      languageName: 'English',
      selfName: 'An',
      nameOf: chatName,
    );
    expect(result, isA<Err<ChatSummary>>());
    verifyNever(
      () => ai.generate(
        key: any(named: 'key'),
        prompt: any(named: 'prompt'),
        model: any(named: 'model'),
      ),
    );
  });
}
