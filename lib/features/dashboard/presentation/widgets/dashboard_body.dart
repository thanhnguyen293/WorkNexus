import 'package:flutter/material.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/zentao_dashboard.dart';
import 'dashboard_queue.dart';
import 'dashboard_rail.dart';

/// The loaded overview: the work queue as the main column beside a narrower
/// one of sprints, todos and activity cards. Below [_twoColumnWidth] the
/// rail moves under the queue.
class DashboardBody extends StatelessWidget {
  const DashboardBody({
    super.key,
    required this.account,
    required this.dashboard,
  });

  final Account account;
  final ZenTaoDashboard dashboard;

  static const double _twoColumnWidth = 900;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final queue = DashboardQueue(account: account);
    final rail = DashboardRail(account: account, dashboard: dashboard);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _twoColumnWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              queue,
              SizedBox(height: s.xl),
              rail,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: queue),
            SizedBox(width: s.xl),
            SizedBox(width: s.xl6 * 9, child: rail),
          ],
        );
      },
    );
  }
}
