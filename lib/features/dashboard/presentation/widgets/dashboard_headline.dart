import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/zentao_dashboard.dart';
import '../../domain/value_objects/dashboard_item_kind.dart';
import '../providers/dashboard_providers.dart';
import 'dashboard_headline_status.dart';
import 'dashboard_profile_line.dart';

/// The dashboard's header: the user's avatar and a sentence that says how
/// much work is waiting — "you have 1 bug and 3 tasks still open." — whose
/// counts open the full lists, over who they are on ZenTao. Today's date, the
/// last update and refresh sit quietly on the right.
class DashboardHeadline extends ConsumerWidget {
  const DashboardHeadline({
    super.key,
    required this.account,
    required this.dashboard,
  });

  final Account account;
  final ZenTaoDashboard? dashboard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final t = context.typography;
    final l = AppL10n.of(context);
    final work = ref.watch(workQueueProvider(account));
    final name = dashboard?.profile.realname ?? account.handle;
    final big = t.display.copyWith(height: 1.3);
    void open(DashboardItemKind kind) =>
        ref.read(dashboardWorkKindProvider.notifier).state = kind;
    final clear = work.openBugs == 0 && work.openTasks == 0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashboardAvatar(name: name),
        SizedBox(width: s.xl3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.dashboardHello(name),
                style: t.title.copyWith(color: c.textSecondary),
              ),
              SizedBox(height: s.xxs),
              Text.rich(
                TextSpan(
                  style: big.copyWith(color: c.textPrimary),
                  children: [
                    TextSpan(text: '${l.dashboardYouHave} '),
                    if (clear)
                      TextSpan(text: l.dashboardAllClear)
                    else ...[
                      _count(
                        l.dashboardBugCount(work.openBugs),
                        big,
                        c.error,
                        () => open(DashboardItemKind.bug),
                      ),
                      TextSpan(text: ' ${l.dashboardAnd} '),
                      _count(
                        l.dashboardTaskCount(work.openTasks),
                        big,
                        c.accent,
                        () => open(DashboardItemKind.task),
                      ),
                      TextSpan(text: ' ${l.dashboardStillOpen}'),
                    ],
                  ],
                ),
              ),
              if (dashboard case final d?) ...[
                SizedBox(height: s.md),
                DashboardProfileLine(dashboard: d),
              ],
            ],
          ),
        ),
        SizedBox(width: s.xl4),
        DashboardHeadlineStatus(account: account, dashboard: dashboard),
      ],
    );
  }

  /// A count inside the sentence, kept on the sentence's baseline.
  InlineSpan _count(
    String text,
    TextStyle style,
    Color color,
    VoidCallback onTap,
  ) => WidgetSpan(
    alignment: PlaceholderAlignment.baseline,
    baseline: TextBaseline.alphabetic,
    child: _CountLink(text: text, style: style, color: color, onTap: onTap),
  );
}

/// The user's initials on a tinted disc.
class DashboardAvatar extends StatelessWidget {
  const DashboardAvatar({super.key, required this.name});

  static const double _size = 56;

  final String name;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w.characters.first.toUpperCase())
        .join();
    return Container(
      width: _size,
      height: _size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.mixT(c.accent, 0.16),
        shape: BoxShape.circle,
      ),
      child: Text(
        initials,
        style: context.typography.titleLg.copyWith(color: c.accent),
      ),
    );
  }
}

/// A count in the headline, tinted by its kind and underlined like a link;
/// the underline takes the full color on hover. Focusable, so the counts open
/// their lists from the keyboard too.
class _CountLink extends StatelessWidget {
  const _CountLink({
    required this.text,
    required this.style,
    required this.color,
    required this.onTap,
  });

  final String text;
  final TextStyle style;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // HoverRegion feeds the underline; HoverSurface adds the tap, keyboard
    // focus ring and button semantics without tinting a fill behind text.
    return HoverRegion(
      cursor: SystemMouseCursors.click,
      builder: (context, hovered, _) => HoverSurface(
        onTap: onTap,
        tintOnHover: false,
        borderRadius: BorderRadius.circular(context.radii.xs),
        child: Text(
          text,
          style: style.copyWith(
            color: color,
            decoration: TextDecoration.underline,
            decorationColor: hovered ? color : c.mixT(color, 0.35),
            decorationThickness: 2,
          ),
        ),
      ),
    );
  }
}
