import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/settings/app_settings.dart';
import '../../../../core/widgets/quick_settings_parts.dart';
import '../../../../core/widgets/quick_settings_segmented.dart';
import '../../../../l10n/app_localizations.dart';

/// The chat text size in Quick Settings: small, default, large, larger.
class ChatTextSizeSetting extends ConsumerWidget {
  const ChatTextSizeSetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final scale = ref.watch(appSettingsProvider.select((s) => s.chatTextScale));
    final labels = [
      l.chatTextSizeSmall,
      l.chatTextSizeDefault,
      l.chatTextSizeLarge,
      l.chatTextSizeLarger,
    ];
    // The nearest offered size, should a stored value be off the list.
    final selected = kChatTextScales.reduce(
      (a, b) => (a - scale).abs() <= (b - scale).abs() ? a : b,
    );
    return QuickSettingsField(
      label: l.chatTextSize,
      control: QuickSettingsSegmented<double>(
        value: selected,
        options: {
          for (final (i, value) in kChatTextScales.indexed) value: labels[i],
        },
        onChanged: ref.read(appSettingsProvider.notifier).setChatTextScale,
      ),
    );
  }
}
