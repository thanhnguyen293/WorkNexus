import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/util/relative_time.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/zentao_doc_action.dart';
import 'zentao_doc_history_changes.dart';

/// One numbered entry of a document's history: when, who, what — and, behind
/// its "+", what changed.
class ZenTaoDocHistoryEntry extends ConsumerStatefulWidget {
  const ZenTaoDocHistoryEntry({
    super.key,
    required this.number,
    required this.entry,
    required this.last,
  });

  final int number;
  final ZenTaoDocAction entry;
  final bool last;

  @override
  ConsumerState<ZenTaoDocHistoryEntry> createState() =>
      _ZenTaoDocHistoryEntryState();
}

class _ZenTaoDocHistoryEntryState extends ConsumerState<ZenTaoDocHistoryEntry> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final c = context.colors;
    final s = context.spacing;
    final t = context.typography;
    final entry = widget.entry;
    final changes = entry.changes;
    final dateFormat = ref.watch(
      appSettingsProvider.select((s) => s.dateFormat),
    );
    final dot = context.sizes.iconLg;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The numbered dot, on a line joining it to the next entry.
          SizedBox(
            width: dot,
            child: Column(
              children: [
                Container(
                  width: dot,
                  height: dot,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.card,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.border),
                  ),
                  child: Text(
                    '${widget.number}',
                    style: t.caption.copyWith(color: c.textSecondary),
                  ),
                ),
                if (!widget.last)
                  Expanded(
                    child: Container(
                      width: context.borders.hairline,
                      color: c.border,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: s.lg),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: s.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Who did what, then when — on one line.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: Text.rich(
                          _withActor(
                            _sentence(l, entry),
                            entry.actor,
                            plain: t.secondary.copyWith(color: c.textSecondary),
                            name: t.secondaryStrong.copyWith(
                              color: c.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      if (entry.date case final date?) ...[
                        SizedBox(width: s.sm),
                        Text(
                          formatDate(
                            context,
                            date,
                            format: dateFormat,
                            withTime: true,
                          ),
                          style: t.caption.copyWith(color: c.textTertiary),
                        ),
                      ],
                    ],
                  ),
                  if (_open && changes.isNotEmpty) ...[
                    SizedBox(height: s.sm),
                    ZenTaoDocHistoryChanges(changes),
                  ],
                ],
              ),
            ),
          ),
          if (changes.isNotEmpty)
            Align(
              alignment: Alignment.topCenter,
              child: AppIconButton(
                icon: _open ? LucideIcons.minus300 : LucideIcons.plus300,
                tooltip: _open ? l.docsHideChanges : l.docsShowChanges,
                size: AppIconButtonSize.small,
                outlined: true,
                onPressed: () => setState(() => _open = !_open),
              ),
            ),
        ],
      ),
    );
  }

  /// [sentence] with the [actor]'s name standing out from the words around
  /// it.
  static TextSpan _withActor(
    String sentence,
    String? actor, {
    required TextStyle plain,
    required TextStyle name,
  }) {
    final at = actor == null || actor.isEmpty ? -1 : sentence.indexOf(actor);
    if (at < 0) return TextSpan(text: sentence, style: plain);
    final end = at + actor!.length;
    return TextSpan(
      style: plain,
      children: [
        if (at > 0) TextSpan(text: sentence.substring(0, at)),
        TextSpan(text: actor, style: name),
        if (end < sentence.length) TextSpan(text: sentence.substring(end)),
      ],
    );
  }

  /// "ViPham edited it" in the app's language for the actions it knows;
  /// ZenTao's own sentence otherwise.
  static String _sentence(AppL10n l, ZenTaoDocAction e) {
    final name = e.actor;
    if (name == null) return e.summary;
    return switch (e.action) {
      'created' || 'opened' => l.docsActionCreated(name),
      'edited' => l.docsActionEdited(name),
      'saveddraft' => l.docsActionSavedDraft(name),
      'moved' => l.docsActionMoved(name),
      'releaseddoc' || 'released' => l.docsActionReleased(name),
      'commented' => l.docsActionCommented(name),
      _ => e.summary,
    };
  }
}
