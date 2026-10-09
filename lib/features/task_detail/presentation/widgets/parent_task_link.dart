import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../util/open_zentao_task.dart';

/// A subtask's parent, shown by its title: tapping it opens the parent in the
/// detail panel — fetched from ZenTao first when it has not been synced.
class ParentTaskLink extends ConsumerStatefulWidget {
  const ParentTaskLink({
    super.key,
    required this.ticket,
    required this.parentId,
    this.parentName,
  });

  /// The subtask.
  final Ticket ticket;
  final String parentId;
  final String? parentName;

  @override
  ConsumerState<ParentTaskLink> createState() => _ParentTaskLinkState();
}

class _ParentTaskLinkState extends ConsumerState<ParentTaskLink> {
  bool _opening = false;

  String get _id => '${widget.ticket.accountId}:${widget.parentId}';

  Future<void> _open() async {
    final messenger = ScaffoldMessenger.of(context);
    final l = AppL10n.of(context);
    setState(() => _opening = true);
    final res = await openZenTaoTask(ref, widget.ticket, widget.parentId);
    if (!mounted) return;
    setState(() => _opening = false);
    if (res case Err(:final failure)) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.actionFailed(failure.message))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final name = widget.parentName ?? ref.watch(ticketByIdProvider(_id))?.title;
    final radius = BorderRadius.circular(context.radii.sm);
    return Material(
      color: c.selectionFill,
      borderRadius: radius,
      child: InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
        onTap: _opening ? null : _open,
        borderRadius: radius,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: s.md, vertical: s.xs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                PhosphorIconsLight.treeStructure,
                size: s.xl3,
                color: c.accent,
              ),
              SizedBox(width: s.sm),
              Text(
                l.parentTask,
                style: context.typography.bodySm.copyWith(
                  color: c.textSecondary,
                ),
              ),
              SizedBox(width: s.sm),
              Text(
                '#${widget.parentId}',
                style: context.typography.mono.copyWith(color: c.accent),
              ),
              if (name != null) ...[
                SizedBox(width: s.sm),
                Flexible(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.bodySm.copyWith(
                      color: c.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              SizedBox(width: s.xs),
              if (_opening)
                SizedBox.square(
                  dimension: s.lg,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.6,
                    color: c.accent,
                  ),
                )
              else
                Icon(
                  PhosphorIconsLight.caretRight,
                  size: s.lg,
                  color: c.accent,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
