import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/zentao_doc_change.dart';

/// What a history entry changed, field by field: an old value struck
/// through and the new one beside it, a text diff's removed and added lines,
/// or — for the body, which ZenTao records as the editor's raw page — just
/// that it changed. Long values are cut to a few lines.
class ZenTaoDocHistoryChanges extends StatelessWidget {
  const ZenTaoDocHistoryChanges(this.changes, {super.key});

  final List<ZenTaoDocChange> changes;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(s.md),
      decoration: BoxDecoration(
        color: c.surfaceSubtle,
        borderRadius: BorderRadius.circular(context.radii.sm),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < changes.length; i++) ...[
            if (i > 0) SizedBox(height: s.md),
            _Change(changes[i]),
          ],
        ],
      ),
    );
  }
}

class _Change extends StatelessWidget {
  const _Change(this.change);

  final ZenTaoDocChange change;

  /// Lines of a value shown before it is cut.
  static const _lines = 3;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final c = context.colors;
    final t = context.typography;
    final body = t.bodySm.copyWith(color: c.textPrimary);
    final gone = body.copyWith(
      color: c.error,
      decoration: TextDecoration.lineThrough,
      decorationColor: c.error,
    );
    final come = body.copyWith(color: c.success);
    // A text diff is often code: mono keeps its columns.
    final mono = t.mono.copyWith(fontSize: t.bodySm.fontSize);
    final goneLine = gone.merge(mono);
    final comeLine = come.merge(mono);
    String shown(String? v) => (v ?? '').trim().isEmpty ? l.docsEmptyValue : v!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          change.field,
          style: t.captionStrong.copyWith(color: c.textSecondary),
        ),
        SizedBox(height: context.spacing.xxs),
        if (change.isBody)
          Text(l.docsBodyChanged, style: body.copyWith(color: c.textTertiary))
        else if (change.removed.isNotEmpty || change.added.isNotEmpty) ...[
          for (final line in change.removed)
            Text(
              line,
              maxLines: _lines,
              overflow: TextOverflow.ellipsis,
              style: goneLine,
            ),
          for (final line in change.added)
            Text(
              line,
              maxLines: _lines,
              overflow: TextOverflow.ellipsis,
              style: comeLine,
            ),
        ] else
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: shown(change.from), style: gone),
                TextSpan(
                  text: '  →  ',
                  style: body.copyWith(color: c.textTertiary),
                ),
                TextSpan(text: shown(change.to), style: come),
              ],
            ),
            maxLines: _lines * 2,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}
