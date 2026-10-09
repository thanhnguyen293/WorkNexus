import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';

/// The chat text size in Quick Settings: small, default, large, larger.
class ChatTextSizeSetting extends ConsumerWidget {
  const ChatTextSizeSetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final c = context.colors;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.chatTextSize,
          style: context.typography.bodyStrong.copyWith(color: c.textPrimary),
        ),
        SizedBox(height: context.spacing.md),
        SegmentedButton<double>(
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: [
            for (final (i, value) in kChatTextScales.indexed)
              ButtonSegment(value: value, label: Text(labels[i])),
          ],
          selected: {selected},
          onSelectionChanged: (picked) => ref
              .read(appSettingsProvider.notifier)
              .setChatTextScale(picked.first),
        ),
      ],
    );
  }
}
