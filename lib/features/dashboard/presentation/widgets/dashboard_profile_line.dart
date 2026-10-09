import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/util/relative_time.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/zentao_dashboard.dart';
import 'my_work_meta.dart';

/// Who the user is on ZenTao — role, email, last login — and how much they
/// take part in (projects, products, docs). Facts the server left out are
/// skipped.
class DashboardProfileLine extends ConsumerWidget {
  const DashboardProfileLine({super.key, required this.dashboard});

  final ZenTaoDashboard dashboard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spacing;
    final l = AppL10n.of(context);
    final format = ref.watch(appSettingsProvider.select((s) => s.dateFormat));
    final d = dashboard;
    final p = d.profile;
    final contributions = [
      if (d.projectTotal case final n? when n > 0) l.dashboardProjectCount(n),
      if (d.productTotal case final n? when n > 0) l.dashboardProductCount(n),
      if (d.docTotal case final n? when n > 0) l.dashboardDocCount(n),
    ];
    return Wrap(
      spacing: s.xl,
      runSpacing: s.xs,
      children: [
        MyWorkFact(
          icon: PhosphorIconsLight.identificationBadge,
          text: [p.account, ?p.role].join(' · '),
        ),
        if (p.email case final email? when email.isNotEmpty)
          MyWorkFact(icon: PhosphorIconsLight.envelopeSimple, text: email),
        if (p.lastLogin case final at?)
          MyWorkFact(
            icon: PhosphorIconsLight.signIn,
            text: l.dashboardLastLogin(formatWhen(context, at, format: format)),
          ),
        if (contributions.isNotEmpty)
          MyWorkFact(
            icon: PhosphorIconsLight.folders,
            text: contributions.join(' · '),
          ),
      ],
    );
  }
}
