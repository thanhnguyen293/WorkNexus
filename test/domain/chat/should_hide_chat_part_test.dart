import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/settings/chat_privacy.dart';
import 'package:work_nexus/features/chat/domain/usecases/should_hide_chat_part.dart';
import 'package:work_nexus/features/chat/domain/value_objects/chat_privacy_part.dart';

void main() {
  const shouldHide = ShouldHideChatPart();

  test('hides nothing while the privacy mode is off', () {
    for (final part in ChatPrivacyPart.values) {
      expect(shouldHide(const ChatPrivacy(), part), isFalse, reason: '$part');
    }
  });

  test('hides every part by default once the mode is on', () {
    for (final part in ChatPrivacyPart.values) {
      expect(
        shouldHide(const ChatPrivacy(enabled: true), part),
        isTrue,
        reason: '$part',
      );
    }
  });

  test('leaves the parts the user turned off clear', () {
    const privacy = ChatPrivacy(
      enabled: true,
      hidePreviews: false,
      hideMessages: false,
    );
    expect(shouldHide(privacy, ChatPrivacyPart.preview), isFalse);
    expect(shouldHide(privacy, ChatPrivacyPart.identity), isTrue);
    expect(shouldHide(privacy, ChatPrivacyPart.message), isFalse);
  });
}
