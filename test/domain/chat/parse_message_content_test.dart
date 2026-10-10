import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/chat/domain/usecases/parse_message_content.dart';
import 'package:work_nexus/features/chat/domain/value_objects/message_content.dart';

void main() {
  const parse = ParseMessageContent();

  test('plain and text are both text', () {
    expect(
      parse('plain', 'hi [@Dyno](@#31)'),
      const MessageContent.text('hi [@Dyno](@#31)'),
    );
    expect(parse('text', '1'), const MessageContent.text('1', markdown: true));
  });

  test('image content as sent by the server', () {
    expect(
      parse(
        'image',
        '{"name":"image.png","size":52247,"send":true,"type":"image/png","id":27338,"time":1790842835000,"width":712,"height":579}',
      ),
      const MessageContent.image(
        fileId: 27338,
        name: 'image.png',
        size: 52247,
        time: 1790842835000,
        mimeType: 'image/png',
        width: 712,
        height: 579,
      ),
    );
  });

  test('file content tolerates numeric strings', () {
    expect(
      parse('file', '{"name":"spec.pdf","size":"1024","id":"9","time":5}'),
      const MessageContent.file(
        fileId: 9,
        name: 'spec.pdf',
        size: 1024,
        time: 5,
      ),
    );
  });

  test('url objects become link cards', () {
    expect(
      parse(
        'object',
        '{"type":"url","url":"https://zt/task-view-12406.html","title":"Task 12406"}',
      ),
      const MessageContent.link(
        url: 'https://zt/task-view-12406.html',
        title: 'Task 12406',
      ),
    );
  });

  test('malformed or unknown content degrades to unsupported', () {
    expect(
      parse('image', 'not json'),
      const MessageContent.unsupported('image'),
    );
    expect(
      parse('image', '{"name":"x.png"}'),
      const MessageContent.unsupported('image'),
    );
    expect(
      parse('object', '{"type":"card"}'),
      const MessageContent.unsupported('object'),
    );
    expect(
      parse('emoticon', ':)'),
      const MessageContent.unsupported('emoticon'),
    );
  });

  test('an image still uploading keeps its size for the bubble', () {
    expect(
      parse('image', '{"name":"shot.png","size":68,"width":320,"height":200}'),
      const MessageContent.image(
        fileId: 0,
        name: 'shot.png',
        size: 68,
        time: 0,
        width: 320,
        height: 200,
      ),
    );
  });
}
