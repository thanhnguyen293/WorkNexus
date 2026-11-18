import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/settings/app_settings.dart';
import '../../domain/usecases/should_blur_chat_part.dart';
import '../../domain/value_objects/chat_privacy_part.dart';

/// Whether the privacy mode blurs [ChatPrivacyPart] right now.
final chatPrivacyBlurProvider = Provider.autoDispose
    .family<bool, ChatPrivacyPart>(
      (ref, part) => const ShouldBlurChatPart()(
        ref.watch(appSettingsProvider.select((s) => s.chatPrivacy)),
        part,
      ),
    );

/// Flips the privacy mode on or off, keeping the parts it blurs.
void toggleChatPrivacyMode(WidgetRef ref) {
  final settings = ref.read(appSettingsProvider.notifier);
  final privacy = ref.read(appSettingsProvider).chatPrivacy;
  settings.setChatPrivacy(privacy.copyWith(enabled: !privacy.enabled));
}
