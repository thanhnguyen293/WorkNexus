import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/chat/domain/usecases/decode_emoji.dart';
import 'package:work_nexus/features/chat/domain/usecases/encode_emoji.dart';
import 'package:work_nexus/features/chat/domain/usecases/parse_message_content.dart';
import 'package:work_nexus/features/chat/domain/value_objects/message_content.dart';

void main() {
  const encode = EncodeEmoji();
  const decode = DecodeEmoji();

  test('known emoji become shortnames, others numeric entities', () {
    expect(encode('👍'), ':thumbsup:');
    expect(encode('ok 😂!'), 'ok :joy:!');
    expect(encode('🦀'), '&#x1F980;');
    expect(encode('Tiếng Việt ❤'), 'Tiếng Việt ❤');
  });

  test('shortnames, aliases and entities decode back', () {
    expect(decode(':thumbsup: :+1:'), '👍 👍');
    expect(decode('&#x1F980; &#128077;'), '🦀 👍');
    expect(decode('at 10:30: done :unknown:'), 'at 10:30: done :unknown:');
  });

  test('round trip keeps the text', () {
    const text = 'Xong rồi 👍🎉 🦀';
    expect(decode(encode(text)), text);
  });

  test('the official large emoji is its own content', () {
    final content = const ParseMessageContent()(
      'image',
      '{"type":"emoji","content":":smile:"}',
    );
    expect(content, const MessageContent.emoji('😄'));
  });

  test('the newer "emotion" content type is a large emoji too', () {
    const parse = ParseMessageContent();
    expect(
      parse('emotion', '{"type":"emoji","content":":thumbsup:"}'),
      const MessageContent.emoji('👍'),
    );
    expect(parse('emotion', ':smile:'), const MessageContent.emoji('😄'));
  });
}
