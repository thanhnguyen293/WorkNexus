import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/chat/domain/usecases/parse_message_content.dart';
import 'package:work_nexus/features/chat/domain/value_objects/message_content.dart';

void main() {
  const parse = ParseMessageContent();

  test('inline images accept bare base64 and data URIs', () {
    for (final content in ['iVBORw0K', 'data:image/png;base64,iVBORw0K']) {
      final image = parse(
        'image',
        '{"name":"image.png","size":5,"type":"base64","content":"$content"}',
      );
      expect((image as ImageContent).inlineBase64, 'iVBORw0K');
    }
  });
}
