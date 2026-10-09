import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/error/result.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/chat_doodle_palette.dart';
import '../../../../core/widgets/app_context_menu.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/wallpaper_providers.dart';
import 'chat_attachments.dart';
import 'chat_snack.dart';
import 'chat_wallpaper.dart';

/// "Wallpaper" in the chat style panel — one background for every chat
/// style: the plain app background, the doodle pattern, or one of the
/// user's images (+ adds one, right-click removes it), and how much an
/// image is darkened.
class ChatWallpaperPicker extends ConsumerWidget {
  const ChatWallpaperPicker({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final files = await pickChatAttachments(imagesOnly: true);
    if (files.isEmpty) return;
    final file = files.first;
    final result = await ref
        .read(wallpaperControllerProvider)
        .add(file.bytes, file.name);
    if (result case Err(:final failure)) {
      if (context.mounted) showChatFailure(context, failure);
    }
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    String path,
    Offset at,
  ) async {
    final l = AppL10n.of(context);
    final remove = await showAppContextMenu(
      context,
      at: at,
      entries: [
        AppMenuEntry(
          icon: PhosphorIconsLight.trash,
          label: l.chatWallpaperRemove,
          destructive: true,
        ),
      ],
    );
    if (remove == null) return;
    final result = await ref.read(wallpaperControllerProvider).remove(path);
    if (result case Err(:final failure)) {
      if (context.mounted) showChatFailure(context, failure);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final c = context.colors;
    final s = context.spacing;
    final (current, dim) = ref.watch(
      appSettingsProvider.select((s) => (s.chatWallpaper, s.chatWallpaperDim)),
    );
    final settings = ref.read(appSettingsProvider.notifier);
    final images = switch (ref.watch(chatWallpapersProvider)) {
      AsyncData(value: Ok(:final value)) => value,
      _ => const <String>[],
    };
    final usingImage =
        chatWallpaperIsPicture(current) && current != kChatWallpaperPattern;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.chatWallpaper,
          style: context.typography.bodyStrong.copyWith(color: c.textPrimary),
        ),
        SizedBox(height: s.md),
        Wrap(
          spacing: s.md,
          runSpacing: s.md,
          children: [
            _Tile(
              label: l.chatWallpaperDefault,
              selected: !chatWallpaperIsPicture(current),
              onTap: () => settings.setChatWallpaper(kChatWallpaperPlain),
              child: ColoredBox(color: c.background),
            ),
            _Tile(
              label: l.chatWallpaperPattern,
              selected: current == kChatWallpaperPattern,
              onTap: () => settings.setChatWallpaper(kChatWallpaperPattern),
              child: ChatWallpaper(
                doodle: ChatDoodlePalette.of(Theme.of(context).brightness),
                scale: 0.3,
                child: const SizedBox.expand(),
              ),
            ),
            for (final path in images)
              GestureDetector(
                onSecondaryTapDown: (d) =>
                    _remove(context, ref, path, d.globalPosition),
                child: _Tile(
                  selected: current == path,
                  onTap: () => settings.setChatWallpaper(path),
                  child: Image.file(
                    File(path),
                    fit: BoxFit.cover,
                    cacheWidth: (s.xl6 * 4).round(),
                    errorBuilder: (_, _, _) => Icon(
                      PhosphorIconsLight.imageBroken,
                      color: c.textTertiary,
                    ),
                  ),
                ),
              ),
            _Tile(
              label: l.chatWallpaperAdd,
              selected: false,
              onTap: () => _add(context, ref),
              child: ColoredBox(
                color: c.surfaceSubtle,
                child: Icon(
                  PhosphorIconsLight.imageSquare,
                  color: c.textSecondary,
                ),
              ),
            ),
          ],
        ),
        if (usingImage) ...[
          SizedBox(height: s.md),
          Row(
            children: [
              Text(
                l.chatWallpaperDim,
                style: context.typography.bodySm.copyWith(
                  color: c.textSecondary,
                ),
              ),
              Expanded(
                child: Slider(
                  value: dim.clamp(0, 0.8),
                  max: 0.8,
                  onChanged: settings.setChatWallpaperDim,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// A square choice: preview, optional label underneath, accent ring when
/// [selected].
class _Tile extends StatelessWidget {
  const _Tile({
    required this.selected,
    required this.onTap,
    required this.child,
    this.label,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final size = s.xl6 * 1.9;
    final radius = BorderRadius.circular(context.radii.md);
    final tile = HoverSurface(
      onTap: onTap,
      width: size,
      height: size,
      padding: EdgeInsets.all(selected ? 2 : 1),
      borderRadius: radius,
      // The picture covers the fill, so the frame answers hover instead.
      tintOnHover: false,
      border: Border.all(
        color: selected ? c.accent : c.border,
        width: selected ? 2 : 1,
      ),
      hoverBorder: Border.all(
        color: selected ? c.accent : c.borderStrong,
        width: selected ? 2 : 1,
      ),
      child: ClipRRect(borderRadius: radius, child: child),
    );
    final text = label;
    if (text == null) return tile;
    return Tooltip(message: text, child: tile);
  }
}
