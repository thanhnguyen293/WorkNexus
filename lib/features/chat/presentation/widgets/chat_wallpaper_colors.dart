import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/settings/app_settings.dart';
import '../../../../core/settings/chat_wallpaper_color.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/chat_doodle_palette.dart';
import '../../../../core/widgets/quick_settings_parts.dart';
import '../../../../core/widgets/swatch_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/wallpaper_providers.dart';
import 'chat_wallpaper.dart';
import 'chat_wallpaper_custom_color.dart';

/// The wallpaper colours under the colour tile: the app's plain background,
/// the presets (each in the theme's shade), a last swatch that opens a free
/// picker right below them,
/// and — once a colour is the wallpaper — whether the doodle pattern is
/// drawn over it.
class ChatWallpaperColors extends ConsumerStatefulWidget {
  const ChatWallpaperColors({super.key});

  @override
  ConsumerState<ChatWallpaperColors> createState() =>
      _ChatWallpaperColorsState();
}

class _ChatWallpaperColorsState extends ConsumerState<ChatWallpaperColors> {
  bool _picking = false;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final s = context.spacing;
    final brightness = Theme.of(context).brightness;
    // What is on screen, so the swatches follow a colour being dragged.
    final chosen = ChatWallpaperColor.parse(
      ref.watch(shownChatWallpaperProvider),
    );
    final settings = ref.read(appSettingsProvider.notifier);
    // A colour still being tried out in the picker gives way to this choice.
    final preview = ref.read(chatWallpaperPreviewProvider.notifier);
    const presets = ChatWallpaperTint.presets;
    final preset = presets.where((t) => t.id == chosen?.color).firstOrNull;
    final custom = chosen != null && preset == null
        ? ChatDoodlePalette.forColor(chosen.color, brightness)?.base
        : null;
    final doodles = chosen?.doodles ?? true;
    final plain = !chatWallpaperIsPicture(
      ref.watch(shownChatWallpaperProvider),
    );

    // A new colour keeps the pattern choice; the first one starts with it.
    void pick(ChatWallpaperTint tint) {
      setState(() => _picking = false);
      preview.clear();
      settings.setChatWallpaper(
        ChatWallpaperColor(tint.id, doodles: doodles).value,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, box) {
            final gap = s.xs;
            final count = presets.length + 2;
            // As many as fit in one row, no bigger than a comfortable dot.
            final size = math.min(
              (box.maxWidth - gap * (count - 1)) / count,
              s.xl6,
            );
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                // The app's own background, no colour of its own.
                SwatchButton(
                  size: size,
                  color: context.colors.background,
                  selected: plain,
                  tooltip: l.chatWallpaperDefault,
                  onTap: () {
                    setState(() => _picking = false);
                    preview.clear();
                    settings.setChatWallpaper(kChatWallpaperPlain);
                  },
                ),
                for (final tint in presets)
                  SwatchButton(
                    size: size,
                    color: tint.of(brightness),
                    selected: preset == tint,
                    onTap: () => pick(tint),
                  ),
                SwatchButton(
                  size: size,
                  color: custom,
                  selected: custom != null || _picking,
                  tooltip: l.colorCustom,
                  onTap: () => setState(() => _picking = !_picking),
                ),
              ],
            );
          },
        ),
        if (_picking) ...[
          SizedBox(height: s.md),
          ChatWallpaperCustomColor(
            initial:
                custom ?? (preset ?? ChatWallpaperTint.green).of(brightness),
            doodles: doodles,
          ),
        ],
        if (chosen != null)
          QuickSettingsSwitchField(
            label: l.chatWallpaperDoodles,
            value: chosen.doodles,
            onChanged: (on) =>
                settings.setChatWallpaper(chosen.copyWith(doodles: on).value),
          ),
      ],
    );
  }
}
