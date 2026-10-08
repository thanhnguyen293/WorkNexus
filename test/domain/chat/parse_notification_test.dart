import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/chat/domain/usecases/parse_message_content.dart';
import 'package:work_nexus/features/chat/domain/value_objects/message_content.dart';

void main() {
  const parse = ParseMessageContent();

  test('object content is merged in, like the official client', () {
    final content = parse(
      'notification',
      jsonEncode({
        'contentType': 'object',
        'content': jsonEncode({
          'title': 'Bug #7 resolved',
          'url': 'https://zentao.example/bug-view-7.html',
        }),
        'actions': {'label': 'Close it', 'url': 'https://zentao.example/x'},
        'sender': 'Lan',
      }),
    );

    expect(
      content,
      const MessageContent.notification(
        title: 'Bug #7 resolved',
        url: 'https://zentao.example/bug-view-7.html',
        actions: [
          NotificationAction(
            label: 'Close it',
            url: 'https://zentao.example/x',
          ),
        ],
        sender: 'Lan',
      ),
    );
  });

  test('plain text stays plain; emoji shortnames decode', () {
    final content = parse(
      'notification',
      jsonEncode({'content': 'Done :thumbsup:', 'contentType': 'plain'}),
    );

    expect(
      content,
      const MessageContent.notification(text: 'Done 👍', markdown: false),
    );
  });
}
