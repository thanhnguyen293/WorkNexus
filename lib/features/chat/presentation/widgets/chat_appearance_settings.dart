import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/settings/app_settings.dart';
import '../../../../core/settings/chat_appearance.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../core/widgets/quick_settings_parts.dart';
import '../../../../l10n/app_localizations.dart';
import 'chat_style.dart';
import 'chat_style_preview.dart';
import 'chat_text_size_setting.dart';
import 'chat_wallpaper_picker.dart';

const int _kColumns = 3;

/// Messenger names are brands and stay as they are in every language.
String chatAppearanceLabel(AppL10n l, ChatAppearance a) => switch (a) {
  ChatAppearance.worknexus => l.chatAppearanceDefault,
  ChatAppearance.telegram => 'Telegram',
  ChatAppearance.zalo => 'Zalo',
  ChatAppearance.messenger => 'Messenger',
  ChatAppearance.wechat => 'WeChat',
  ChatAppearance.tbchat => 'TBChat',
};

/// The chat's look, as a Quick Settings section: a preview card per style,
/// the wallpaper shared by every style and, for the messenger styles,
/// whether own bubbles use the app's accent. Picks apply at once.
class ChatAppearanceSettings extends ConsumerWidget {
  const ChatAppearanceSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final s = context.spacing;
    final (current, primary) = ref.watch(
      appSettingsProvider.select(
        (s) => (s.chatAppearance, s.chatPrimaryBubbles),
      ),
    );
    final settings = ref.read(appSettingsProvider.notifier);
    return QuickSettingsSection(
      title: l.quickSettingsChatLook,
      children: [
        QuickSettingsField(
          label: l.chatAppearance,
          stacked: true,
          control: LayoutBuilder(
            builder: (context, box) {
              final cardWidth =
                  (box.maxWidth - s.md * (_kColumns - 1)) / _kColumns;
              return Wrap(
                spacing: s.md,
                runSpacing: s.md,
                children: [
                  for (final a in ChatAppearance.values)
                    SizedBox(
                      width: cardWidth,
                      child: _StyleCard(
                        appearance: a,
                        selected: a == current,
                        style: ChatStyle.of(
                          a,
                          context,
                          primaryBubbles: primary,
                        ),
                        onTap: () => settings.setChatAppearance(a),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        const ChatTextSizeSetting(),
        const ChatWallpaperPicker(),
        QuickSettingsSwitchField(
          label: l.chatPrimaryBubbles,
          hint: l.chatPrimaryBubblesHint,
          value: primary,
          // The default style already follows the app's colours.
          onChanged: current == ChatAppearance.worknexus
              ? null
              : settings.setChatPrimaryBubbles,
        ),
      ],
    );
  }
}

class _StyleCard extends StatelessWidget {
  const _StyleCard({
    required this.appearance,
    required this.selected,
    required this.style,
    required this.onTap,
  });

  final ChatAppearance appearance;
  final bool selected;
  final ChatStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final radius = BorderRadius.circular(context.radii.lg);
    return Semantics(
      selected: selected,
      button: true,
      child: HoverSurface(
        onTap: onTap,
        padding: EdgeInsets.all(s.sm),
        borderRadius: radius,
        border: Border.all(
          color: selected ? c.accent : c.border,
          width: selected ? 2 : 1,
        ),
        hoverBorder: Border.all(
          color: selected ? c.accent : c.borderStrong,
          width: selected ? 2 : 1,
        ),
        child: Column(
          children: [
            // Laid out at the size it was designed for, scaled to the card.
            AspectRatio(
              aspectRatio: 3.4 / 2.4,
              child: FittedBox(
                child: SizedBox(
                  width: s.xl6 * 3.4,
                  height: s.xl6 * 2.4,
                  child: ChatStylePreview(style: style),
                ),
              ),
            ),
            SizedBox(height: s.sm),
            Row(
              children: [
                Expanded(
                  child: Text(
                    chatAppearanceLabel(AppL10n.of(context), appearance),
                    style: context.typography.bodySmStrong.copyWith(
                      color: selected ? c.accent : c.textPrimary,
                    ),
                  ),
                ),
                if (selected)
                  Icon(
                    PhosphorIconsFill.checkCircle,
                    size: s.xl3,
                    color: c.accent,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
