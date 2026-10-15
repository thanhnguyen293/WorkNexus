import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/coming_soon_view.dart';
import '../../../../l10n/app_localizations.dart';

/// The Workspace Members placeholder page (design §5, specs S6.4).
/// Displays a ComingSoonView explaining that connections are shared.
class MembersPage extends StatelessWidget {
  const MembersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);

    return ColoredBox(
      color: c.background,
      child: ComingSoonView(
        icon: LucideIcons.users300,
        title: l.members,
        body: l.membersComingSoonBody,
      ),
    );
  }
}
