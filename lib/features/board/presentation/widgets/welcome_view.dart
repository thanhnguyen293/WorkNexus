import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/widgets/app_state_view.dart';
import '../../../../l10n/app_localizations.dart';

/// The launch/home screen shown before any source is selected. Deliberately
/// minimal: an app glyph, the title, and a hint to pick a source from the
/// sidebar. No toolbar and no board — those appear once a view is opened.
class WelcomeView extends StatelessWidget {
  const WelcomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return AppStateView.empty(
      icon: LucideIcons.layoutGrid300,
      title: l.welcomeTitle,
      message: l.welcomeHint,
    );
  }
}
