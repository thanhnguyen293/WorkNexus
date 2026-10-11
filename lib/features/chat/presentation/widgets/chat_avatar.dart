import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/contrast.dart';
import '../../domain/value_objects/chat_presence.dart';
import 'chat_labels.dart';
import 'chat_verified_legend.dart';

/// Avatar sizes used by chat.
enum ChatAvatarSize { small, medium, large }

/// The "verified" check of a leading role: its colour and the role.
typedef ChatVerifiedBadge = ({Color color, String role});

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
    this.presence,
    this.label,
    this.background,
    this.verified,
  });

  /// Draws a "verified" check (a leading role, see [chatVerifiedBadge]) at
  /// the top right; hovering it explains it.
  final ChatVerifiedBadge? verified;

  final String name;

  /// Draws a status dot (green online, amber away, red busy; none when
  /// offline or unknown).
  final ChatPresence? presence;

  /// Text drawn instead of the initials (a group's text avatar).
  final String? label;

  /// Fill behind the initials/label (a group's text avatar colour).
  final Color? background;
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
    final initials = _Initials(
      name: name,
      diameter: diameter,
      label: label,
      background: background,
    );
    final url = imageUrl;
    final picture = SizedBox.square(
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
    final c = context.colors;
    final dot = chatPresenceColor(context, presence);
    if (dot == null && verified == null) return picture;
    final dotSize = (diameter * 0.3).clamp(s.md, s.xl3);
    final checkSize = (diameter * 0.36).clamp(s.lg, s.xl5);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        picture,
        if (verified case (:final color, :final role))
          Positioned(
            right: -checkSize * 0.15,
            top: -checkSize * 0.15,
            // The glyph's check is a cut-out: a small white dot inside the
            // badge (not a ring around it) makes it read white on any photo.
            child: Tooltip(
              richMessage: WidgetSpan(child: ChatVerifiedLegend(role: role)),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(context.radii.md),
                border: Border.all(color: c.border),
                boxShadow: [
                  BoxShadow(
                    color: c.scrim.withValues(alpha: 0.18),
                    blurRadius: s.xl4,
                  ),
                ],
              ),
              padding: EdgeInsets.all(s.lg),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: checkSize * 0.5,
                    height: checkSize * 0.5,
                    decoration: BoxDecoration(
                      color: c.onScrim,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Icon(Icons.verified_rounded, size: checkSize, color: color),
                ],
              ),
            ),
          ),
        if (dot != null)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: dot,
                shape: BoxShape.circle,
                border: Border.all(color: c.surface, width: dotSize * 0.18),
              ),
            ),
          ),
      ],
    );
  }
}

/// How strongly an initials avatar is tinted with its hue.
const double _kInitialsTint = 0.22;

/// The avatar hue for [name]: one of the theme's semantic colours, picked by
/// a stable hash of the name (String.hashCode can differ between runs).
Color _avatarHue(AppColors c, String name) {
  final hues = [c.accent, c.success, c.warning, c.info, c.caution, c.error];
  var hash = 0;
  for (final unit in name.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return hues[hash % hues.length];
}

class _Initials extends StatelessWidget {
  const _Initials({
    required this.name,
    required this.diameter,
    this.label,
    this.background,
  });

  final String name;
  final double diameter;
  final String? label;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final big = diameter > context.spacing.xl5;
    final custom = label != null && label!.trim().isNotEmpty;
    // A hue of its own per name (stable across launches), so an avatar is
    // told apart from its neighbours and from the selected row's tint.
    // Opaque: a tinted fill would let the chat wallpaper show through.
    final hue = _avatarHue(c, name);
    final fill =
        background ??
        Color.alphaBlend(hue.withValues(alpha: _kInitialsTint), c.surface);
    final ink = background == null
        ? readableOn(hue, fill, towards: c.textPrimary)
        : c.onAccent;
    // Two letters don't fit a tiny avatar (a board card's): it shows one, and
    // the letter shrinks with the circle instead of filling it.
    final tiny = diameter < context.spacing.xl5;
    final initials = chatInitials(name);
    final base = big
        ? context.typography.captionStrong
        : context.typography.captionSm;
    final fitted = diameter * (tiny ? 0.5 : 0.4);
    return ColoredBox(
      color: Color.alphaBlend(fill, c.surface),
      child: Center(
        child: Text(
          custom
              ? label!.trim()
              : tiny
              ? initials.characters.take(1).toString()
              : initials,
          maxLines: 1,
          style: base.copyWith(
            color: ink,
            fontWeight: FontWeight.w600,
            fontSize: math.min(base.fontSize ?? fitted, fitted),
          ),
        ),
      ),
    );
  }
}

/// The colour of a presence dot; null when nothing is shown (offline or
/// unknown).
Color? chatPresenceColor(BuildContext context, ChatPresence? presence) {
  final c = context.colors;
  return switch (presence) {
    ChatPresence.online => c.success,
    ChatPresence.away => c.warning,
    ChatPresence.busy => c.error,
    ChatPresence.meeting => c.info,
    ChatPresence.offline || null => null,
  };
}
