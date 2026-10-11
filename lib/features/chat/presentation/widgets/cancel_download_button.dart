import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/widgets/app_icon_button.dart';
import '../../../../l10n/app_localizations.dart';

/// A small ✕ beside a file that is downloading (or uploading): stops it.
class CancelDownloadButton extends StatelessWidget {
  const CancelDownloadButton({
    super.key,
    required this.onPressed,
    this.color,
    this.tooltip,
  });

  final VoidCallback onPressed;

  /// Defaults to "Cancel download".
  final String? tooltip;

  /// Icon colour; defaults to the secondary text colour.
  final Color? color;

  @override
  Widget build(BuildContext context) => AppIconButton(
    icon: LucideIcons.x300,
    tooltip: tooltip ?? AppL10n.of(context).chatCancelDownload,
    size: AppIconButtonSize.small,
    color: color,
    onPressed: onPressed,
  );
}
