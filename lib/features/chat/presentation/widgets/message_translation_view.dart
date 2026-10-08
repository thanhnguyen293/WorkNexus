import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/message_translation_controller.dart';
import 'chat_bubble_theme.dart';

/// The translation of a message, under its text — a spinner while it runs, the
/// translated text, or the reason it failed. Nothing until one is requested.
class MessageTranslationView extends ConsumerWidget {
  const MessageTranslationView({
    super.key,
    required this.accountId,
    required this.gid,
  });

  final String accountId;
  final String gid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(
      messageTranslationControllerProvider.select((m) => m[gid]),
    );
    final stored = ref
        .watch(messageTranslationProvider((accountId: accountId, gid: gid)))
        .asData
        ?.value;
    final shown = stored != null && stored.visible ? stored : null;
    if (pending == null && shown == null) return const SizedBox.shrink();
    final ink = ChatBubbleTheme.of(context);
    final l = AppL10n.of(context);
    final s = context.spacing;
    final style = context.typography.body.copyWith(
      color: ink.text,
      fontSize: ink.fontSize,
      height: 1.5,
    );
    final child = switch (pending) {
      MessageTranslation(loading: true) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: s.xl,
            child: CircularProgressIndicator(strokeWidth: 2, color: ink.meta),
          ),
          SizedBox(width: s.md),
          Text(
            l.chatTranslating,
            style: style.copyWith(color: ink.meta, fontStyle: FontStyle.italic),
          ),
        ],
      ),
      MessageTranslation(:final error?) => Text(
        l.chatTranslateFailed(error),
        style: style.copyWith(color: ink.meta, fontStyle: FontStyle.italic),
      ),
      _ => SelectableText(shown?.text ?? '', style: style),
    };
    final byline = pending != null || shown == null
        ? null
        : l.chatTranslatedBy(shown.model ?? 'OpenCode');
    return Padding(
      padding: EdgeInsets.only(top: s.sm),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: ink.meta.withValues(alpha: 0.1),
          border: Border.all(color: ink.meta.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(context.radii.md),
        ),
        child: Padding(
          padding: EdgeInsets.all(s.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              child,
              if (byline != null)
                Padding(
                  padding: EdgeInsets.only(top: s.sm),
                  child: Text(
                    byline,
                    style: context.typography.captionSm.copyWith(
                      color: ink.meta,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
