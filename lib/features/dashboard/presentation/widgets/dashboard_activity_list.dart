import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/semantic.dart';
import '../../../../core/widgets/zentao_kind_icon.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/dashboard_activity.dart';
import '../../domain/value_objects/dashboard_item_kind.dart';
import '../util/open_dashboard_item.dart';
import '../util/short_when.dart';

/// Recent activity as a timeline — the object's kind icon on one thin line:
/// who did what to which object, its title, and when. Activity on a bug,
/// task or story opens it in the detail panel.
class DashboardActivityList extends StatelessWidget {
  const DashboardActivityList({
    super.key,
    required this.account,
    required this.activities,
  });

  final Account account;
  final List<DashboardActivity> activities;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < activities.length; i++)
        _Activity(
          account: account,
          activity: activities[i],
          last: i == activities.length - 1,
        ),
    ],
  );
}

class _Activity extends ConsumerWidget {
  const _Activity({
    required this.account,
    required this.activity,
    required this.last,
  });

  final Account account;
  final DashboardActivity activity;

  /// The last event ends the timeline's line.
  final bool last;

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    DashboardItemKind kind,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = AppL10n.of(context).dashboardOpenFailed;
    final res = await openDashboardItem(ref, account, kind, activity.objectId);
    if (res is Err) messenger.showSnackBar(SnackBar(content: Text(failed)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final t = context.typography;
    final a = activity;
    final kind = DashboardItemKind.fromObjectType(a.objectType);
    final opensTicket = kind != null && kind.isTicket && a.objectId.isNotEmpty;
    final name = a.objectName;
    return InkWell(
      mouseCursor: WidgetStateMouseCursor.clickable,
      onTap: opensTicket ? () => _open(context, ref, kind) : null,
      borderRadius: BorderRadius.circular(context.radii.md),
      hoverColor: c.selectionFill,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              children: [
                ZenTaoKindIcon(a.objectType),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 1,
                      margin: EdgeInsets.symmetric(vertical: s.xs),
                      color: c.border,
                    ),
                  ),
              ],
            ),
            SizedBox(width: s.lg),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: s.xl, right: s.xs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: a.actor,
                                  style: t.bodySmStrong.copyWith(
                                    color: c.textPrimary,
                                  ),
                                ),
                                TextSpan(text: ' ${a.action} '),
                                TextSpan(
                                  text: ticketRef(
                                    ProviderType.zentao,
                                    a.objectId,
                                    _capitalized(a.objectType),
                                  ),
                                  style: t.monoSm.copyWith(
                                    color: c.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                            style: t.bodySm.copyWith(color: c.textSecondary),
                          ),
                        ),
                        SizedBox(width: s.md),
                        Text(
                          shortWhen(context, a.date),
                          style: t.caption.copyWith(color: c.textTertiary),
                        ),
                      ],
                    ),
                    if (name != null && name.isNotEmpty) ...[
                      SizedBox(height: s.xxs),
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodySm.copyWith(color: c.textPrimary),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _capitalized(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
