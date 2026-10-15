import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/semantic.dart';
import '../../../../core/widgets/badges.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../core/widgets/tinted_pill.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/assigned_work_item.dart';
import '../util/short_when.dart';

/// A single open assigned work row on the Workspace Overview (design §5, specs S6.1).
/// Displays provider badge, monospace key, title, status pill, and relative time/due.
/// Clicking it opens the detail slide-over via [openTicket].
class AssignedWorkRow extends ConsumerWidget {
  const AssignedWorkRow({super.key, required this.item, this.now});

  final AssignedWorkItem item;
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final currentTime = now ?? DateTime.now();

    return HoverSurface(
      onTap: () => ref.read(appNavProvider.notifier).openTicket(item.ticketId),
      borderRadius: BorderRadius.circular(context.radii.sm),
      padding: EdgeInsets.symmetric(horizontal: s.md, vertical: s.sm),
      child: Row(
        children: [
          ProviderBadge(item.provider),
          SizedBox(width: s.sm),
          SizedBox(
            width: 80,
            child: Text(
              item.displayKey,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.typography.monoSm.copyWith(
                color: c.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(width: s.sm),
          Expanded(
            child: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.typography.bodySm.copyWith(color: c.textPrimary),
            ),
          ),
          SizedBox(width: s.md),
          TintedPill(
            color: statusColor(c, item.status),
            label: item.statusLabel,
          ),
          SizedBox(width: s.md),
          _TimeLabel(item: item, now: currentTime),
        ],
      ),
    );
  }
}

class _TimeLabel extends StatelessWidget {
  const _TimeLabel({required this.item, required this.now});

  final AssignedWorkItem item;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final locale = Localizations.localeOf(context).toString();

    if (item.due != null) {
      final due = item.due!.toLocal();
      final isOverdue = due.isBefore(now);
      final formattedDate = DateFormat.MMMd(locale).format(due);
      final text = isOverdue
          ? l.overdueRelative(formattedDate)
          : l.dueRelative(formattedDate);

      return SizedBox(
        width: 100,
        child: Text(
          text,
          textAlign: TextAlign.end,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.typography.captionSm.copyWith(
            color: isOverdue ? c.error : c.textTertiary,
            fontWeight: isOverdue ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      );
    }

    final relativeTime = shortWhen(context, item.updatedAt, now: now);
    return SizedBox(
      width: 100,
      child: Text(
        relativeTime,
        textAlign: TextAlign.end,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.typography.captionSm.copyWith(color: c.textTertiary),
      ),
    );
  }
}
