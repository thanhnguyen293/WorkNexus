import 'package:flutter/material.dart';

import '../../../../core/theme/app_radii.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../l10n/app_localizations.dart';
import 'chat_user_profile_dialog.dart';

/// Makes [child] (an avatar or a sender name) open that user's profile.
/// Hovering names the user — an avatar alone does not say who it is.
class ChatProfileTap extends StatelessWidget {
  const ChatProfileTap({
    super.key,
    required this.accountId,
    required this.userId,
    required this.name,
    required this.child,
    this.showName = true,
  });

  final String accountId;
  final int userId;

  /// The user's display name.
  final String name;
  final Widget child;

  /// Off when [child] already shows [name], so hovering does not repeat it.
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final tap = HoverSurface(
      borderRadius: BorderRadius.circular(context.radii.sm),
      semanticLabel: AppL10n.of(context).chatUserProfileOf(name),
      onTap: () => ChatUserProfileDialog.show(
        context,
        accountId: accountId,
        userId: userId,
      ),
      child: child,
    );
    return showName ? Tooltip(message: name, child: tap) : tap;
  }
}
