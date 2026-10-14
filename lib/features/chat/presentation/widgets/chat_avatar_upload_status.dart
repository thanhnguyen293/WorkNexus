import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';

/// Where changing the user's own picture stands.
sealed class ChatAvatarUpload {
  const ChatAvatarUpload();
}

final class ChatAvatarUploading extends ChatAvatarUpload {
  const ChatAvatarUploading();
}

final class ChatAvatarUploaded extends ChatAvatarUpload {
  const ChatAvatarUploaded();
}

final class ChatAvatarUploadFailed extends ChatAvatarUpload {
  const ChatAvatarUploadFailed(this.reason);
  final String reason;
}

/// One line under the profile's avatar saying how its change went — inside
/// the dialog, since a toast would sit behind its barrier.
class ChatAvatarUploadStatus extends StatelessWidget {
  const ChatAvatarUploadStatus({super.key, required this.upload});

  final ChatAvatarUpload upload;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final iconSize = context.sizes.iconSm;
    final (Widget glyph, String text, Color color) = switch (upload) {
      ChatAvatarUploading() => (
        SizedBox.square(
          dimension: iconSize,
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
        l.chatMyAvatarUploading,
        c.textSecondary,
      ),
      ChatAvatarUploaded() => (
        Icon(LucideIcons.circleCheck300, size: iconSize, color: c.success),
        l.chatMyAvatarUpdated,
        c.success,
      ),
      ChatAvatarUploadFailed(:final reason) => (
        Icon(LucideIcons.circleAlert300, size: iconSize, color: c.error),
        l.chatMyAvatarFailed(reason),
        c.error,
      ),
    };
    return Semantics(
      liveRegion: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          glyph,
          SizedBox(width: context.spacing.sm),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: context.typography.bodySm.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
