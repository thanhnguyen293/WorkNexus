import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/chat_providers.dart';
import 'chat_labels.dart';

/// Laid over an own image while it uploads: the picture dims under a ring
/// filling with the upload and the percentage sent.
class ChatUploadOverlay extends ConsumerWidget {
  const ChatUploadOverlay({super.key, required this.messageGid});

  final String messageGid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    // Null until the first chunk reports: the ring spins instead.
    final sent = ref.watch(chatUploadProgressProvider(messageGid)).value;
    return ColoredBox(
      color: c.scrim.withValues(alpha: 0.35),
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: s.lg, vertical: s.md),
          decoration: BoxDecoration(
            color: c.scrim.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(s.xl3),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: s.xl3,
                child: CircularProgressIndicator(
                  value: sent,
                  strokeWidth: 2.5,
                  color: c.onAccent,
                  backgroundColor: c.onAccent.withValues(alpha: 0.25),
                ),
              ),
              SizedBox(width: s.md),
              Text(
                formatPercent(sent ?? 0),
                style: context.typography.captionStrong.copyWith(
                  color: c.onAccent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
