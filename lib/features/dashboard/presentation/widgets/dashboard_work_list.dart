import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/value_objects/priority.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/badges.dart';
import '../../../../core/widgets/zentao_kind_icon.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/dashboard_work_item.dart';
import '../../domain/value_objects/dashboard_item_kind.dart';
import '../util/dashboard_status_color.dart';
import '../util/open_dashboard_item.dart';
import 'dashboard_row.dart';
import 'my_work_meta.dart';

/// The rows of a "my work" card. Tickets open in the detail panel.
class DashboardWorkList extends ConsumerWidget {
  const DashboardWorkList({
    super.key,
    required this.account,
    required this.items,
  });

  final Account account;
  final List<DashboardWorkItem> items;

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    DashboardWorkItem item,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = AppL10n.of(context).dashboardOpenFailed;
    final res = await openDashboardItem(ref, account, item.kind, item.id);
    if (res is Err) messenger.showSnackBar(SnackBar(content: Text(failed)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = AppL10n.of(context);
    return Column(
      children: [
        for (final item in items)
          DashboardRow(
            leading: ZenTaoKindIcon(item.kind.name),
            title: item.title,
            subtitle: item.context,
            trailing: [
              if (item.deadline case final due?) MyWorkDueFact(due),
              if (item.priority case final pri? when pri > 0)
                PriorityTag(ProviderType.zentao, Priority.fromLevel(pri - 1)),
              if (item.status case final status?)
                MyWorkStatusChip(
                  label: item.statusLabel ?? _statusLabel(l, status),
                  color: dashboardStatusColor(
                    c,
                    status,
                    bug: item.kind == DashboardItemKind.bug,
                  ),
                ),
            ],
            onTap: item.kind.isTicket ? () => _open(context, ref, item) : null,
          ),
      ],
    );
  }

  /// ZenTao's todo status codes, for when the server sends no label.
  static String _statusLabel(AppL10n l, String status) => switch (status) {
    'wait' => l.myWorkStatusWaiting,
    'doing' => l.myWorkStatusDoing,
    'done' => l.myWorkStatusDone,
    'closed' => l.myWorkStatusClosed,
    _ => status,
  };
}
