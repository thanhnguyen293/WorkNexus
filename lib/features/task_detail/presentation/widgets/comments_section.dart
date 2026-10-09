import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/domain/entities/activity_event.dart';
import '../../../../core/domain/entities/comment.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/util/body_format.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../sync/data/sync_service.dart';
import '../detail_providers.dart';
import '../util/image_fallback.dart';
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
        for (final (_, item) in items)
          switch (item) {
            final Comment cm => CommentTile(
              cm,
              html: isHtmlBody(ticket.providerType, cm.body),
              imageLoader: (url) =>
                  getIt<SyncService>().fetchTicketImage(ticket, url),
              imageFallback: imageFallback,
            ),
            final ActivityEvent a => ActivityRow(a),
            _ => const SizedBox.shrink(),
          },
        SizedBox(height: context.spacing.md),
        _Composer(ticket: ticket),
      ],
    );
  }
}

/// Writes a comment and posts it to the provider; the refreshed thread
/// (written to drift by the detail sync) then shows it.
class _Composer extends StatefulWidget {
  const _Composer({required this.ticket});

  final Ticket ticket;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final _text = TextEditingController();
  bool _posting = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final text = _text.text.trim();
    if (text.isEmpty || _posting) return;
    final messenger = ScaffoldMessenger.of(context);
    final failed = AppL10n.of(context).commentPostFailed;
    setState(() => _posting = true);
    final res = await getIt<SyncService>().postComment(widget.ticket, text);
    if (!mounted) return;
    setState(() => _posting = false);
    switch (res) {
      case Ok():
        _text.clear();
      case Err():
        messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(context.radii.md),
      borderSide: BorderSide(color: color),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        TextField(
          controller: _text,
          minLines: 2,
          maxLines: 8,
          style: context.typography.body.copyWith(color: c.textPrimary),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: c.surfaceSubtle,
            hintText: l.writeCommentHint,
            hintStyle: context.typography.body.copyWith(color: c.textTertiary),
            border: border(c.border),
            enabledBorder: border(c.border),
            focusedBorder: border(c.accent),
          ),
        ),
        SizedBox(height: context.spacing.md),
        AppButton.filled(
          size: AppButtonSize.small,
          isLoading: _posting,
          onPressed: _post,
          child: Text(l.commentAction),
        ),
      ],
    );
  }
}
