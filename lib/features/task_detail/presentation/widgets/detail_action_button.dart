import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';

/// A compact outlined icon+label button used by the provider action bars in the
/// detail panel. Disabled when [onTap] is null (e.g. while an action is busy).
class DetailActionButton extends StatelessWidget {
  const DetailActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppButton.outlinedNeutral(
      size: AppButtonSize.small,
      onPressed: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15),
          SizedBox(width: context.spacing.sm),
          Text(label),
        ],
      ),
    );
  }
}
