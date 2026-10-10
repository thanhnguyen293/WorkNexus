import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/domain/entities/activity_event.dart';
import '../../../../core/domain/entities/comment.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/util/body_format.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../sync/data/sync_service.dart';
import '../detail_providers.dart';
import '../util/image_fallback.dart';
import 'comment_composer.dart';
import 'comment_tile.dart';

/// The ticket's comments and activity as one timeline, oldest first, with a
/// composer under it that posts to the provider. Sits at the foot of the
/// "Original" tab, below the description.
class CommentsSection extends ConsumerWidget {
  const CommentsSection({
    super.key,
    required this.ticket,
    required this.imageFallback,
  });

  final Ticket ticket;

  /// Comments share the ticket's provider context, so inline images get the
  /// same "open in browser" fallback as the description.
  final ImageFallback imageFallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final comments = [
      for (final cm
          in ref.watch(commentsProvider(ticket.id)).asData?.value ??
              const <Comment>[])
        // Local-only notes are gone as a feature; old ones stay hidden.
        if (cm.origin == CommentOrigin.provider) cm,
    ];
    // Activity that isn't a comment (comments are drawn as cards).
    final activity =
        (ref.watch(activityProvider(ticket.id)).asData?.value ??
                const <ActivityEvent>[])
            .where((a) => a.action != 'commented');
    final items = <(DateTime, Object)>[
      for (final cm in comments) (cm.createdAt, cm),
      for (final a in activity) (a.at, a),
    ]..sort((x, y) => x.$1.compareTo(y.$1));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (items.isEmpty)
          Text(
            AppL10n.of(context).noActivityYet,
            style: context.typography.secondary.copyWith(color: c.textTertiary),
          ),
        for (final (i, (_, item)) in items.indexed)
          switch (item) {
            final Comment cm => CommentTile(
              cm,
              html: isHtmlBody(ticket.providerType, cm.body),
              isFirst: i == 0,
              isLast: i == items.length - 1,
              imageLoader: (url) =>
                  getIt<SyncService>().fetchTicketImage(ticket, url),
              imageFallback: imageFallback,
            ),
            final ActivityEvent a => ActivityRow(
              a,
              isFirst: i == 0,
              isLast: i == items.length - 1,
            ),
            _ => const SizedBox.shrink(),
          },
        SizedBox(height: context.spacing.md),
        CommentComposer(ticket: ticket),
      ],
    );
  }
}
