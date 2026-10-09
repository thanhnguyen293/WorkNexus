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

  test('a ZenTao action card shows its item, not raw JSON', () {
    final content = parse(
      'notification',
      jsonEncode({
        'title': 'JunNg-VN-Flutter assigned 1 Bug',
        'content': jsonEncode({
          'action': 'assigned',
          'object': '6492',
          'objectName': '[Discover] Feed: Video autoplay is delayed',
          'objectType': 'bug',
          'id': '6492',
          'count': 1,
          'headSubTitle': 'VN_Socialfi',
          'cardURL': 'https://zentao.example/zentao/bug-view-6492.html',
        }),
      }),
    );

    expect(
      content,
      const MessageContent.notification(
        title: 'JunNg-VN-Flutter assigned 1 Bug',
        subtitle: 'VN_Socialfi',
        text: '#6492 [Discover] Feed: Video autoplay is delayed',
        markdown: false,
        url: 'https://zentao.example/zentao/bug-view-6492.html',
      ),
    );
  });

  test('a card for several items says how many more', () {
    final content = parse(
      'notification',
      jsonEncode({
        'content': jsonEncode({
          'objectName': 'First task',
          'id': '12',
          'count': 3,
        }),
      }),
    );

    expect((content as NotificationContent).text, '#12 First task (+2)');
  });

  test('the card link wins over the official client\'s app link', () {
    final content = parse(
      'notification',
      jsonEncode({
        'url':
            'xxc:openInApp/zentao-integrated/'
            'https%3A%2F%2Fzentao.example%2Fzentao%2Fbug-view-1.html',
        'content': jsonEncode({
          'objectName': 'Crash',
          'id': '6492',
          'cardURL': 'https://zentao.example/zentao/bug-view-6492.html',
        }),
      }),
    );

    expect(
      (content as NotificationContent).url,
      'https://zentao.example/zentao/bug-view-6492.html',
    );
  });

  test('an app link alone is unwrapped to the page it opens', () {
    final content = parse(
      'notification',
      jsonEncode({
        'title': 'Build done',
        'url':
            'xxc:openInApp/zentao-integrated/'
            'https%3A%2F%2Fzentao.example%2Fzentao%2Ftask-view-9.html',
      }),
    );

    expect(
      (content as NotificationContent).url,
      'https://zentao.example/zentao/task-view-9.html',
    );
  });
}
