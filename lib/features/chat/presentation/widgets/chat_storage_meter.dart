import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_cache_usage.dart';
import 'chat_labels.dart';
import 'chat_storage_bar.dart';

/// The cache at a glance: how much is used (large) against the limit, a bar
/// for the limit split by kind — photos, videos, files, other — and their
/// legend. The figure turns to the warning colour near the limit.
class ChatStorageMeter extends StatelessWidget {
  const ChatStorageMeter({
    super.key,
    required this.usage,
    required this.limitBytes,
  });

  final ChatCacheUsage usage;
  final int limitBytes;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final used = usage.totalBytes;
    final ratio = limitBytes <= 0 ? 0.0 : (used / limitBytes).clamp(0.0, 1.0);
    final near = ratio > 0.9;
    int sum(int Function(ChatCacheChatUsage) of) =>
        usage.chats.fold(0, (total, chat) => total + of(chat));
    final kinds = [
      ...chatStorageKinds(
        context,
        imageBytes: sum((u) => u.imageBytes),
        videoBytes: sum((u) => u.videoBytes),
        fileBytes: sum((u) => u.fileBytes),
      ),
      (
        label: l.chatStorageOther,
        bytes: usage.otherBytes,
        color: c.textTertiary,
      ),
    ];
    return Container(
      padding: EdgeInsets.all(s.xl3),
      decoration: BoxDecoration(
        color: c.surfaceSubtle,
        borderRadius: BorderRadius.circular(context.radii.lg),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                formatFileSize(used),
                style: context.typography.titleLg.copyWith(
                  color: near ? c.warning : c.textPrimary,
                ),
              ),
              SizedBox(width: s.sm),
              Text(
                '/ ${formatFileSize(limitBytes)}',
                style: context.typography.secondary.copyWith(
                  color: c.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                formatPercent(ratio),
                style: context.typography.secondaryStrong.copyWith(
                  color: near ? c.warning : c.textSecondary,
                ),
              ),
            ],
          ),
          SizedBox(height: s.lg),
          ChatStorageBar(
            total: limitBytes,
            parts: [for (final k in kinds) (bytes: k.bytes, color: k.color)],
            height: s.lg,
          ),
          if (used > 0) ...[
            SizedBox(height: s.lg),
            ChatStorageLegend(kinds: kinds),
          ],
        ],
      ),
    );
  }
}
