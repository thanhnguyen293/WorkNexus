import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import 'chat_labels.dart';

/// Avatar sizes used by chat.
enum ChatAvatarSize { small, medium, large }

/// Avatar outline: round, or a rounded square (WeChat).
enum ChatAvatarShape { circle, roundedSquare }

/// A round avatar: the user's ZenTao picture when they have one (served by
/// ZenTao itself, publicly), else their initials.
class ChatAvatar extends StatelessWidget {
  const ChatAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = ChatAvatarSize.medium,
    this.shape = ChatAvatarShape.circle,
    this.diameter,
  });

  final String name;
  final String? imageUrl;
  final ChatAvatarSize size;
  final ChatAvatarShape shape;

  /// Exact size in logical px; overrides [size] (chat styles use their own).
  final double? diameter;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final diameter =
        this.diameter ??
        switch (size) {
          ChatAvatarSize.small => s.xl5,
          ChatAvatarSize.medium => s.xl6 * 0.9,
          ChatAvatarSize.large => s.xl6 * 1.1,
        };
    final initials = _Initials(name: name, diameter: diameter);
    final url = imageUrl;
    return SizedBox.square(
      dimension: diameter,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          shape == ChatAvatarShape.circle ? diameter / 2 : diameter * 0.12,
        ),
        child: url == null || url.isEmpty
            ? initials
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, _) => initials,
                errorWidget: (_, _, _) => initials,
              ),
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.name, required this.diameter});

  final String name;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final big = diameter > context.spacing.xl5;
    return ColoredBox(
      color: c.selectionFill,
      child: Center(
        child: Text(
          chatInitials(name),
          style:
              (big
                      ? context.typography.captionStrong
                      : context.typography.captionSm)
                  .copyWith(color: c.accent, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
