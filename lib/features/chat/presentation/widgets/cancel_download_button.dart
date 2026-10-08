import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';

/// A small ✕ beside a file that is downloading: stops the download.
class CancelDownloadButton extends StatelessWidget {
  const CancelDownloadButton({super.key, required this.onPressed, this.color});

  final VoidCallback onPressed;

  /// Icon colour; defaults to the secondary text colour.
  final Color? color;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: AppL10n.of(context).chatCancelDownload,
    onPressed: onPressed,
    visualDensity: VisualDensity.compact,
    icon: Icon(
      PhosphorIconsLight.x,
      size: context.spacing.xl3,
      color: color ?? context.colors.textSecondary,
    ),
  );
}
