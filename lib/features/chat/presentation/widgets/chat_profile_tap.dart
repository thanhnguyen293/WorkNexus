import 'package:flutter/material.dart';

import '../../../../core/theme/app_radii.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../l10n/app_localizations.dart';
import 'chat_user_profile_dialog.dart';

/// Makes [child] (an avatar or a sender name) open that user's profile.
class ChatProfileTap extends StatelessWidget {
  const ChatProfileTap({
    super.key,
    required this.accountId,
    required this.userId,
    required this.child,
  });

  final String accountId;
  final int userId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final label = AppL10n.of(context).chatUserProfile;
    return Tooltip(
      message: label,
      child: HoverSurface(
        borderRadius: BorderRadius.circular(context.radii.sm),
        semanticLabel: label,
        onTap: () => ChatUserProfileDialog.show(
          context,
          accountId: accountId,
          userId: userId,
        ),
        child: child,
      ),
    );
  }
}
