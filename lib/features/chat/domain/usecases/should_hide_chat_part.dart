import '../../../../core/settings/chat_privacy.dart';
import '../value_objects/chat_privacy_part.dart';

/// Whether [ChatPrivacy] hides [ChatPrivacyPart] right now: only while the
/// privacy mode is on, and only the parts the user picked.
class ShouldHideChatPart {
  const ShouldHideChatPart();

  bool call(ChatPrivacy privacy, ChatPrivacyPart part) =>
      privacy.enabled &&
      switch (part) {
        ChatPrivacyPart.preview => privacy.hidePreviews,
        ChatPrivacyPart.identity => privacy.hideIdentities,
        ChatPrivacyPart.message => privacy.hideMessages,
      };
}
