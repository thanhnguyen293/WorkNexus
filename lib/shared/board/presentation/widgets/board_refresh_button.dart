import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/widgets/app_icon_button.dart';
import '../../../../l10n/app_localizations.dart';

/// The board toolbar's manual Refresh: fetches the board on screen again from
/// its provider. Each tool says what that means for its board ([onPressed])
/// and whether it is fetching now ([loading]); while it is, a spinner stands
/// in and taps are ignored.
class BoardRefreshButton extends StatelessWidget {
  const BoardRefreshButton({
    super.key,
    required this.loading,
    required this.onPressed,
  });

  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => AppIconButton(
    icon: LucideIcons.rotateCw300,
    tooltip: AppL10n.of(context).refresh,
    isLoading: loading,
    onPressed: onPressed,
  );
}
