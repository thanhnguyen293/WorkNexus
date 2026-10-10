import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import 'chat_labels.dart';

/// One kind of downloaded attachment in a storage breakdown.
typedef ChatStorageKind = ({String label, int bytes, Color color});

/// Photos, videos and files — the kinds every storage view splits into, each
/// in its own colour so the bar, legend and rows read alike.
List<ChatStorageKind> chatStorageKinds(
  BuildContext context, {
  required int imageBytes,
  required int videoBytes,
  required int fileBytes,
}) {
  final c = context.colors;
  final l = AppL10n.of(context);
  return [
    (label: l.chatStoragePhotos, bytes: imageBytes, color: c.accent),
    (label: l.chatStorageVideos, bytes: videoBytes, color: c.info),
    (label: l.chatStorageFiles, bytes: fileBytes, color: c.notice),
  ];
}

/// A bar for [total] bytes with one coloured segment per part, the rest of
/// it the track.
class ChatStorageBar extends StatelessWidget {
  const ChatStorageBar({
    super.key,
    required this.total,
    required this.parts,
    this.height,
  });

  final int total;
  final List<({int bytes, Color color})> parts;

  /// Thickness; the medium spacing step by default.
  final double? height;

  /// Bar resolution: segments are whole thousandths of [total].
  static const _steps = 1000;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final flexes = [
      for (final p in parts)
        p.bytes <= 0 || total <= 0
            ? 0
            // A used part always shows, however small next to the total.
            : (p.bytes * _steps / total).round().clamp(1, _steps).toInt(),
    ];
    final rest = _steps - flexes.fold<int>(0, (sum, f) => sum + f);
    return ClipRRect(
      borderRadius: BorderRadius.circular(context.radii.pill),
      child: SizedBox(
        height: height ?? context.spacing.md,
        child: Row(
          children: [
            for (final (i, p) in parts.indexed)
              if (flexes[i] > 0)
                Expanded(
                  flex: flexes[i],
                  child: ColoredBox(color: p.color),
                ),
            if (rest > 0)
              Expanded(
                flex: rest,
                child: ColoredBox(color: c.border),
              ),
          ],
        ),
      ),
    );
  }
}

/// The kinds' colours with their names and sizes, wrapping on narrow widths.
/// Kinds with nothing stored are left out.
class ChatStorageLegend extends StatelessWidget {
  const ChatStorageLegend({super.key, required this.kinds});

  final List<ChatStorageKind> kinds;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    return Wrap(
      spacing: s.xl3,
      runSpacing: s.sm,
      children: [
        for (final k in kinds)
          if (k.bytes > 0)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: s.md,
                  height: s.md,
                  decoration: BoxDecoration(
                    color: k.color,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: s.sm),
                Text(
                  k.label,
                  style: context.typography.secondary.copyWith(
                    color: c.textPrimary,
                  ),
                ),
                SizedBox(width: s.xs),
                Text(
                  formatFileSize(k.bytes),
                  style: context.typography.secondary.copyWith(
                    color: c.textSecondary,
                  ),
                ),
              ],
            ),
      ],
    );
  }
}
