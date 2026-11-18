import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/settings/chat_privacy.dart';
import 'package:work_nexus/features/chat/domain/usecases/should_blur_chat_part.dart';
import 'package:work_nexus/features/chat/domain/value_objects/chat_privacy_part.dart';

void main() {
  const shouldBlur = ShouldBlurChatPart();

  test('blurs nothing while the privacy mode is off', () {
    for (final part in ChatPrivacyPart.values) {
      expect(shouldBlur(const ChatPrivacy(), part), isFalse, reason: '$part');
    }
  });

  test('blurs every part by default once the mode is on', () {
    for (final part in ChatPrivacyPart.values) {
      expect(
        shouldBlur(const ChatPrivacy(enabled: true), part),
        isTrue,
        reason: '$part',
      );
    }
  });

  test('leaves the parts the user turned off clear', () {
    const privacy = ChatPrivacy(
      enabled: true,
      blurPreviews: false,
      blurMessages: false,
    );
    expect(shouldBlur(privacy, ChatPrivacyPart.preview), isFalse);
    expect(shouldBlur(privacy, ChatPrivacyPart.identity), isTrue);
    expect(shouldBlur(privacy, ChatPrivacyPart.message), isFalse);
  });
}
