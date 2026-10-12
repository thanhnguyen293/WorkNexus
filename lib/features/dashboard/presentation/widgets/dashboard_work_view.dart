import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/inline_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/dashboard_item_kind.dart';
import '../providers/dashboard_providers.dart';
import 'dashboard_work_column.dart';
import 'dashboard_work_header.dart';

/// Everything assigned to the user — the full lists behind the overview,
/// under [DashboardWorkHeader]: tasks and bugs side by side when there is
/// room, else the one [kind] picked in the header. Reads the shared ticket
/// store (synced from ZenTao on open), so rows open straight in the detail
/// panel. Open items by default.
class DashboardWorkView extends ConsumerWidget {
  const DashboardWorkView({
    super.key,
    required this.account,
    required this.kind,
  });

  final Account account;

  /// The list shown when only one fits.
  final DashboardItemKind kind;

  /// From this width tasks and bugs sit side by side; the header follows it.
  static const twoColumnsMinWidth = 960.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spacing;
    final l = AppL10n.of(context);
    final sync = ref.watch(myWorkSyncProvider(account.id));
    final failed = sync.hasError && !sync.isLoading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The lists keep the last synced rows; the failure is said once above.
        if (failed) ...[
          AppInlineNote(text: l.dashboardWorkSyncFailed, isError: true),
          SizedBox(height: s.xl),
        ],
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) => box.maxWidth >= twoColumnsMinWidth
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: DashboardWorkColumn(
                          account: account,
                          kind: DashboardItemKind.task,
                          showTitle: true,
                        ),
                      ),
                      SizedBox(width: s.xl4),
                      Expanded(
                        child: DashboardWorkColumn(
                          account: account,
                          kind: DashboardItemKind.bug,
                          showTitle: true,
                        ),
                      ),
                    ],
                  )
                : DashboardWorkColumn(account: account, kind: kind),
          ),
        ),
      ],
    );
  }
}
