import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_layout.dart';

void main() {
  test('the chat list counts against the info panel room only when it is '
      'beside the messages', () {
    // A 1440px window less the rail and the tool pane, which holds the list.
    const shell = 1064.0;
    expect(ChatLayout.of(shell, withList: false).infoRoom, isTrue);
    expect(ChatLayout.of(shell).infoRoom, isFalse);
  });

  test('without the list, nothing collapses it', () {
    final layout = ChatLayout.of(600, withList: false);
    expect(layout.infoRoom, isFalse);
    expect(layout.compactList, isFalse);
  });
}
