import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_expandable_card.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/panic_switch_config.dart';
import 'panic_app_checklist.dart';
import 'panic_labels.dart';
import 'panic_more_settings.dart';
import 'panic_sender_list.dart';
import 'panic_steps.dart';
import 'panic_try_button.dart';

/// The "Official" tab: the team group trigger — how it works, the apps to
/// open, who may set it off, and the rest folded away.
class PanicReleaseTab extends StatelessWidget {
  const PanicReleaseTab({
    super.key,
    required this.config,
    required this.accountId,
    required this.team,
    required this.canRaise,
  });

  final PanicSwitchConfig config;
  final String accountId;

  /// The team group's title, or a stand-in until it is found.
  final String team;
  final bool canRaise;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final s = context.spacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(s.xl2, s.none, s.xl2, s.xl2),
          child: PanicSteps(
            title: l.panicSwitchHowTitle,
            steps: [
              (
                LucideIcons.mousePointerClick300,
                l.panicSwitchHowStep1(gestureLabel(l, config.overlayGesture)),
              ),
              (LucideIcons.send300, l.panicSwitchHowStep2(team)),
              (LucideIcons.appWindow300, l.panicSwitchHowStep3),
            ],
          ),
        ),
        AppExpandableCardSection(
          title: l.panicSwitchTargetLabel,
          hint: canRaise
              ? l.panicSwitchTargetHint
              : '${l.panicSwitchTargetHint} ${l.panicSwitchWaylandNote}',
          child: PanicAppChecklist(config: config),
        ),
        AppExpandableCardSection(
          title: l.panicSwitchSendersLabel,
          hint: l.panicSwitchSendersHint,
          child: PanicSenderList(accountId: accountId, config: config),
        ),
        AppExpandableCardSection(
          title: l.panicSwitchTryLabel,
          hint: l.panicSwitchTryHint,
          trailing: const PanicTryButton(),
        ),
        PanicMoreSettings(config: config),
      ],
    );
  }
}
