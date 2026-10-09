import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/inline_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/dashboard_providers.dart';
import '../widgets/dashboard_body.dart';
import '../widgets/dashboard_headline.dart';
import '../widgets/dashboard_stat_tiles.dart';
import '../widgets/dashboard_work_header.dart';
import '../widgets/dashboard_work_view.dart';

/// The ZenTao dashboard: the user's open work, sprints and recent activity,
/// or — from a counter or "Show all" — the full list of their tasks or bugs.
/// Shows what is stored at once and refreshes it in the background.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final account = ref.watch(dashboardAccountProvider);
    if (account == null) {
      return ColoredBox(
        color: c.background,
        child: Center(
          child: Text(
            l.dashboardNoAccount,
            style: context.typography.body.copyWith(color: c.textTertiary),
          ),
        ),
      );
    }
    // Keeps the assigned bugs and tasks synced while the dashboard is open.
    ref.watch(myWorkSyncProvider(account.id));
    final workKind = ref.watch(dashboardWorkKindProvider);
    final padding = EdgeInsets.fromLTRB(s.xl5, s.xl4, s.xl5, s.xl5);
    if (workKind != null) {
      return _Layout(
        header: DashboardWorkHeader(account: account, kind: workKind),
        body: Padding(
          padding: padding,
          child: _Frame(
            child: DashboardWorkView(account: account, kind: workKind),
          ),
        ),
      );
    }
    final dashboard = ref.watch(dashboardProvider(account.id)).value;
    final refresh = ref.watch(dashboardRefreshProvider(account.id));
    final failed = refresh.hasError && !refresh.isLoading;
    return _Layout(
      header: DashboardHeadline(account: account, dashboard: dashboard),
      body: SingleChildScrollView(
        padding: padding,
        child: _Frame(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DashboardStatTiles(account: account, dashboard: dashboard),
              SizedBox(height: s.xl),
              if (dashboard != null) ...[
                if (failed) ...[
                  AppInlineNote(text: l.dashboardRefreshFailed, isError: true),
                  SizedBox(height: s.xl),
                ],
                DashboardBody(account: account, dashboard: dashboard),
              ] else if (failed)
                _LoadFailed(
                  onRetry: () => ref
                      .read(dashboardRefreshProvider(account.id).notifier)
                      .refresh(),
                )
              else
                Padding(
                  padding: EdgeInsets.all(s.xl6),
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The page's chrome: [header] on a surface bar set off from the content
/// by a hairline, like the chat header, over the scrolling [body].
class _Layout extends StatelessWidget {
  const _Layout({required this.header, required this.body});

  final Widget header;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    return ColoredBox(
      color: c.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: c.surface,
              border: Border(bottom: context.hairlineSide),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(s.xl5, s.xl, s.xl5, s.xl),
              child: _Frame(child: header),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// Top-centers [child] and stops it growing past a readable width, so the
/// dashboard does not sprawl on wide windows.
class _Frame extends StatelessWidget {
  const _Frame({required this.child});

  static const double _maxContentWidth = 1200;

  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _maxContentWidth),
      child: SizedBox(width: double.infinity, child: child),
    ),
  );
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    return Padding(
      padding: EdgeInsets.all(context.spacing.xl6),
      child: Column(
        children: [
          Text(
            l.dashboardLoadFailed,
            style: context.typography.body.copyWith(color: c.textSecondary),
          ),
          SizedBox(height: context.spacing.md),
          TextButton(onPressed: onRetry, child: Text(l.retry)),
        ],
      ),
    );
  }
}
