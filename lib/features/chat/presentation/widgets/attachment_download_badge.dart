import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/value_objects/message_content.dart';
import '../providers/chat_providers.dart';
import 'chat_labels.dart';

/// What a not-yet-downloaded attachment shows: its size with a download
/// arrow, or the download's progress. Nothing once it is downloaded.
class AttachmentDownloadBadge extends ConsumerWidget {
  const AttachmentDownloadBadge({
    super.key,
    required this.accountId,
    required this.content,
    required this.size,
  });

  final String accountId;
  final MessageContent content;

  /// File size in bytes (0 = unknown, then only the arrow shows).
  final int size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (accountId: accountId, content: content);
    final downloading = ref.watch(
      chatDownloadingProvider.select((d) => d.contains(key)),
    );
    final cached = ref.watch(chatAttachmentCachedProvider(key)).value;
    if (!downloading && cached != false) return const SizedBox.shrink();
    final c = context.colors;
    final s = context.spacing;
    final progress = downloading
        ? ref.watch(chatDownloadProgressProvider(key)).value
        : null;
    final ink = c.onScrim;
    final label = downloading
        ? (progress == null ? null : '${(progress * 100).round()}%')
        : (size > 0 ? formatFileSize(size) : null);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.scrim.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(context.radii.pill),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: s.md, vertical: s.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (downloading)
              SizedBox.square(
                dimension: s.xl,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 2,
                  color: ink,
                  backgroundColor: ink.withValues(alpha: 0.25),
                ),
              )
            else
              Icon(Icons.download_rounded, size: s.xl3, color: ink),
            if (label != null) ...[
              SizedBox(width: s.xs),
              Text(
                label,
                style: context.typography.captionStrong.copyWith(color: ink),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
