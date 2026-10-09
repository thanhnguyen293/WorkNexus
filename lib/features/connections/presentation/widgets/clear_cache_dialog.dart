import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dialog_frame.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/cache_section.dart';

/// Asks which cached data to clear, every section picked to start with;
/// resolves to the picked sections, or null when cancelled.
Future<Set<CacheSection>?> showClearCacheDialog(BuildContext context) =>
    showDialog<Set<CacheSection>>(
      context: context,
      builder: (_) => const _ClearCacheDialog(),
    );

class _ClearCacheDialog extends StatefulWidget {
  const _ClearCacheDialog();

  @override
  State<_ClearCacheDialog> createState() => _ClearCacheDialogState();
}

class _ClearCacheDialogState extends State<_ClearCacheDialog> {
  final _picked = {...CacheSection.values};

  void _toggle(CacheSection section, bool on) => setState(() {
    on ? _picked.add(section) : _picked.remove(section);
  });

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final c = context.colors;
    final s = context.spacing;
    return AppDialogFrame(
      title: l.clearCacheTitle,
      maxWidth: s.xl6 * 11,
      actions: [
        const Spacer(),
        AppButton.textNeutral(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        AppButton.error(
          isDisabled: _picked.isEmpty,
          onPressed: () => Navigator.pop(context, {..._picked}),
          child: Text(l.clearCacheConfirm),
        ),
      ],
      child: Padding(
        padding: EdgeInsets.fromLTRB(s.lg, 0, s.lg, s.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final section in CacheSection.values)
              CheckboxListTile(
                value: _picked.contains(section),
                onChanged: (on) => _toggle(section, on ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                title: Text(
                  _title(l, section),
                  style: context.typography.bodyStrong.copyWith(
                    color: c.textPrimary,
                  ),
                ),
                subtitle: Text(
                  _hint(l, section),
                  style: context.typography.caption.copyWith(
                    color: c.textSecondary,
                  ),
                ),
              ),
            SizedBox(height: s.md),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: s.xl3),
              child: Text(
                l.clearCacheKept,
                style: context.typography.caption.copyWith(
                  color: c.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _title(AppL10n l, CacheSection section) => switch (section) {
  CacheSection.tickets => l.cacheSectionTickets,
  CacheSection.dashboard => l.cacheSectionDashboard,
  CacheSection.chat => l.cacheSectionChat,
  CacheSection.translations => l.cacheSectionTranslations,
};

String _hint(AppL10n l, CacheSection section) => switch (section) {
  CacheSection.tickets => l.cacheSectionTicketsHint,
  CacheSection.dashboard => l.cacheSectionDashboardHint,
  CacheSection.chat => l.cacheSectionChatHint,
  CacheSection.translations => l.cacheSectionTranslationsHint,
};
