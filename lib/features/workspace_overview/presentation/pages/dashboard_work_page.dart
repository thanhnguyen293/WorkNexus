import 'package:flutter/material.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/value_objects/dashboard_item_kind.dart';
import '../widgets/dashboard_work_header.dart';
import '../widgets/dashboard_work_view.dart';

/// Every task and bug assigned to the user on one ZenTao account, shown in
/// the Overview's place from a ZenTao section's "Show all"; the header's back
/// button returns to the Overview.
class DashboardWorkPage extends StatelessWidget {
  const DashboardWorkPage({
    super.key,
    required this.account,
    required this.kind,
  });

  /// Tasks and bugs sit side by side: wider than the Overview's frame.
  static const double _maxWidth = 1600;

  final Account account;
  final DashboardItemKind kind;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    return ColoredBox(
      color: c.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The header on a surface bar set off by a hairline, like chat's.
          DecoratedBox(
            decoration: BoxDecoration(
              color: c.surface,
              border: Border(bottom: context.hairlineSide),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(s.xl5, s.xl, s.xl5, s.xl),
              child: _Frame(
                child: DashboardWorkHeader(account: account, kind: kind),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(s.xl5, s.xl4, s.xl5, s.xl5),
              child: _Frame(
                child: DashboardWorkView(account: account, kind: kind),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Top-centers [child] and stops it growing past a readable width.
class _Frame extends StatelessWidget {
  const _Frame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: DashboardWorkPage._maxWidth),
      child: SizedBox(width: double.infinity, child: child),
    ),
  );
}
