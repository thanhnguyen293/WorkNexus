import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/panic_button_look.dart';
import 'panic_labels.dart';

/// The card's opening lines: what happens, step by step, with the user's own
/// settings (gesture, group, demo chat) filled in.
class PanicHowItWorks extends StatelessWidget {
  const PanicHowItWorks({
    super.key,
    required this.gesture,
    required this.team,
    this.demoChat,
  });

  final PanicGesture gesture;
  final String team;

  /// The demo chat's title, when demo mode is on.
  final String? demoChat;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final c = context.colors;
    final s = context.spacing;
    final demoChat = this.demoChat;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(s.xl2, s.none, s.xl2, s.xl2),
      child: Container(
        padding: EdgeInsets.all(s.lg),
        decoration: BoxDecoration(
          color: c.surfaceSubtle,
          borderRadius: BorderRadius.circular(context.radii.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: s.md,
          children: [
            Text(
              l.panicSwitchHowTitle,
              style: context.typography.bodyStrong.copyWith(
                color: c.textPrimary,
              ),
            ),
            _Step(
              icon: LucideIcons.mousePointerClick300,
              text: l.panicSwitchHowStep1(gestureLabel(l, gesture)),
            ),
            _Step(icon: LucideIcons.send300, text: l.panicSwitchHowStep2(team)),
            _Step(icon: LucideIcons.appWindow300, text: l.panicSwitchHowStep3),
            if (demoChat != null)
              _Step(
                icon: LucideIcons.flaskConical300,
                text: l.panicSwitchHowDemo(demoChat),
              ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: context.spacing.md,
      children: [
        Icon(icon, size: context.sizes.iconSm, color: c.accent),
        Expanded(
          child: Text(
            text,
            style: context.typography.paragraph.copyWith(
              color: c.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
