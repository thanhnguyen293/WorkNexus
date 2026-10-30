import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/value_objects/zentao_ticket_id.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';

/// A subtask card's parent task — its number and title — so a subtask can be
/// placed without opening it. Display only: the whole card is the tap target.
class ZenTaoCardParent extends ConsumerWidget {
  const ZenTaoCardParent({
    super.key,
    required this.accountId,
    required this.parentId,
    this.parentName,
  });

  final String accountId;
  final String parentId;

  /// The parent's title as ZenTao gave it; when missing, the synced parent's.
  final String? parentName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final name =
        parentName ??
        ref.watch(
          ticketByIdProvider(
            zenTaoTicketId(accountId, 'task', parentId),
          ).select((t) => t?.title),
        );
    final style = context.typography.caption.copyWith(color: c.textTertiary);
    return Tooltip(
      message: [AppL10n.of(context).parentTask, '#$parentId', ?name].join(' '),
      child: Row(
        children: [
          Icon(
            LucideIcons.cornerLeftUp300,
            size: context.sizes.iconXs,
            color: c.textTertiary,
          ),
          SizedBox(width: s.xs),
          Text(
            '#$parentId',
            style: context.typography.mono.copyWith(color: c.textTertiary),
          ),
          if (name != null) ...[
            SizedBox(width: s.xs),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
