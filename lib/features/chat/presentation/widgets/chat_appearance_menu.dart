import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/settings/app_settings.dart';
import '../../../../core/settings/chat_appearance.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import 'chat_style.dart';
import 'chat_style_preview.dart';
import 'chat_wallpaper_picker.dart';

const int _kColumns = 3;

/// Header button opening the chat style picker: a preview card per style,
/// the wallpaper and, for the messenger styles, whether own bubbles use the app's accent.
/// Picks apply at once and the panel stays open to compare.
class ChatAppearanceMenu extends StatelessWidget {
  const ChatAppearanceMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return MenuAnchor(
      menuChildren: const [_AppearancePanel()],
      builder: (context, menu, _) => IconButton(
        tooltip: l.chatAppearance,
        isSelected: menu.isOpen,
        onPressed: () => menu.isOpen ? menu.close() : menu.open(),
        icon: Icon(Icons.style_outlined, color: context.colors.textSecondary),
      ),
    );
  }
}

/// Messenger names are brands and stay as they are in every language.
String chatAppearanceLabel(AppL10n l, ChatAppearance a) => switch (a) {
  ChatAppearance.worknexus => l.chatAppearanceDefault,
  ChatAppearance.telegram => 'Telegram',
  ChatAppearance.zalo => 'Zalo',
  ChatAppearance.messenger => 'Messenger',
  ChatAppearance.wechat => 'WeChat',
  ChatAppearance.tbchat => 'TBChat',
};

class _AppearancePanel extends ConsumerWidget {
  const _AppearancePanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final s = context.spacing;
    final c = context.colors;
    final (current, primary) = ref.watch(
      appSettingsProvider.select(
        (s) => (s.chatAppearance, s.chatPrimaryBubbles),
      ),
    );
    final settings = ref.read(appSettingsProvider.notifier);
    final cardWidth = s.xl6 * 3.6;
    return Padding(
      padding: EdgeInsets.all(s.lg),
      child: SizedBox(
        width: cardWidth * _kColumns + s.lg * (_kColumns - 1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.chatAppearance,
              style: context.typography.title.copyWith(color: c.textPrimary),
            ),
            SizedBox(height: s.lg),
            Wrap(
              spacing: s.lg,
              runSpacing: s.lg,
              children: [
                for (final a in ChatAppearance.values)
                  SizedBox(
                    width: cardWidth,
                    child: _StyleCard(
                      appearance: a,
                      selected: a == current,
                      style: ChatStyle.of(a, context, primaryBubbles: primary),
                      onTap: () => settings.setChatAppearance(a),
                    ),
                  ),
              ],
            ),
            _SectionDivider(),
            const ChatWallpaperPicker(),
            _SectionDivider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: primary,
              // The default style already follows the app's colours.
              onChanged: current == ChatAppearance.worknexus
                  ? null
                  : settings.setChatPrimaryBubbles,
              title: Text(
                l.chatPrimaryBubbles,
                style: context.typography.bodyStrong.copyWith(
                  color: c.textPrimary,
                ),
              ),
              subtitle: Text(
                l.chatPrimaryBubblesHint,
                style: context.typography.caption.copyWith(
                  color: c.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A hairline with room around it, between the panel's sections (styles,
/// wallpaper, bubble colour).
class _SectionDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Divider(
    height: context.spacing.xl4 * 1.5,
    thickness: 1,
    color: context.colors.border,
  );
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
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(s.sm),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: selected ? c.accent : c.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              SizedBox(
                height: s.xl6 * 2.4,
                child: ChatStylePreview(style: style),
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
                      Icons.check_circle_rounded,
                      size: s.xl3,
                      color: c.accent,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
