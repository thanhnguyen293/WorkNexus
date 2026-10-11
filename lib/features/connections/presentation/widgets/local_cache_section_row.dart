import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/cache_section.dart';

/// One part of the local database: its icon, name and what it holds, and a
/// checkbox; the whole row toggles it.
class LocalCacheSectionRow extends StatelessWidget {
  const LocalCacheSectionRow({
    required this.section,
    required this.picked,
    required this.onToggle,
    super.key,
  });

  final CacheSection section;
  final bool picked;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    return InkWell(
      mouseCursor: WidgetStateMouseCursor.clickable,
      onTap: onToggle,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: s.lg, vertical: s.lg),
        child: Row(
          children: [
            Container(
              width: s.xl6 * 0.9,
              height: s.xl6 * 0.9,
              decoration: BoxDecoration(
                color: c.surfaceSubtle,
                shape: BoxShape.circle,
              ),
              child: Icon(_icon(section), size: s.xl4, color: c.textSecondary),
            ),
            SizedBox(width: s.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _title(l, section),
                    style: context.typography.bodyStrong.copyWith(
                      color: c.textPrimary,
                    ),
                  ),
                  SizedBox(height: s.xxs),
                  Text(
                    _hint(l, section),
                    style: context.typography.caption.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: s.lg),
            Checkbox(value: picked, onChanged: (_) => onToggle()),
          ],
        ),
      ),
    );
  }
}

IconData _icon(CacheSection section) => switch (section) {
  CacheSection.tickets => LucideIcons.kanban300,
  CacheSection.dashboard => LucideIcons.layoutDashboard300,
  CacheSection.chat => LucideIcons.messagesSquare300,
  CacheSection.translations => LucideIcons.languages300,
};

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
