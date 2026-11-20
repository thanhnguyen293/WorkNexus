import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../core/widgets/tinted_pill.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/chat_presence.dart';
import 'chat_avatar.dart';
import 'chat_labels.dart';

/// The top of the profile popup: a banner in the person's own colour, their
/// avatar overlapping it, then name, handle, presence and role.
class ChatProfileHeader extends StatelessWidget {
  const ChatProfileHeader({
    super.key,
    required this.name,
    required this.avatar,
    required this.avatarDiameter,
    this.handle,
    this.presence,
    this.role,
  });

  final String name;

  /// The avatar, drawn at [avatarDiameter].
  final Widget avatar;
  final double avatarDiameter;

  /// Their login, shown as `@handle`.
  final String? handle;
  final ChatPresence? presence;

  /// Their role's display name.
  final String? role;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final banner = avatarDiameter * 1.1;
    final ring = s.xs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: banner + avatarDiameter / 2 + ring,
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: banner,
                child: _Banner(hue: chatNameHue(c, name)),
              ),
              Positioned(top: s.lg, right: s.lg, child: const _CloseButton()),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  padding: EdgeInsets.all(ring),
                  decoration: BoxDecoration(
                    color: c.surface,
                    shape: BoxShape.circle,
                  ),
                  child: avatar,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: s.lg),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: s.xl5),
          child: SelectableText(
            name,
            textAlign: TextAlign.center,
            style: context.typography.titleLg.copyWith(color: c.textPrimary),
          ),
        ),
        SizedBox(height: s.xs),
        _StatusLine(handle: handle, presence: presence),
        if (role case final role?) ...[
          SizedBox(height: s.lg),
          Center(
            child: TintedPill(
              color: c.accent,
              icon: LucideIcons.briefcase300,
              label: role,
              large: true,
              pill: true,
            ),
          ),
        ],
      ],
    );
  }
}

/// A diagonal wash of the person's colour into the accent, with two soft
/// rings for depth.
class _Banner extends StatelessWidget {
  const _Banner({required this.hue});

  final Color hue;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final glow = c.onScrim.withValues(alpha: 0.1);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            hue,
            Color.lerp(hue, c.accent, 0.7)!.withValues(alpha: 0.85),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: -s.xl6,
            top: -s.xl6 * 1.5,
            child: _Ring(diameter: s.xl6 * 4, color: glow),
          ),
          Positioned(
            right: -s.xl6,
            bottom: -s.xl6 * 2,
            child: _Ring(diameter: s.xl6 * 3.5, color: glow),
          ),
        ],
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.diameter, required this.color});

  final double diameter;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: diameter,
    height: diameter,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}

/// Close, on a dark disc so it reads on any banner colour.
class _CloseButton extends StatelessWidget {
  const _CloseButton();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final label = AppL10n.of(context).close;
    return Tooltip(
      message: label,
      child: HoverSurface(
        semanticLabel: label,
        shape: BoxShape.circle,
        color: c.scrim.withValues(alpha: 0.3),
        hoverColor: c.scrim.withValues(alpha: 0.5),
        width: context.sizes.controlMd,
        height: context.sizes.controlMd,
        alignment: Alignment.center,
        onTap: () => Navigator.of(context).pop(),
        child: Icon(
          LucideIcons.x300,
          size: context.sizes.iconMd,
          color: c.onScrim,
        ),
      ),
    );
  }
}

/// `@handle · ● Online`, the dot in the presence colour.
class _StatusLine extends StatelessWidget {
  const _StatusLine({this.handle, this.presence});

  final String? handle;
  final ChatPresence? presence;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final style = context.typography.secondary.copyWith(color: c.textSecondary);
    final presence = this.presence;
    final dot = chatPresenceColor(context, presence) ?? c.textTertiary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (handle case final handle?)
          Flexible(
            child: Text(
              '@$handle',
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (handle != null && presence != null)
          Text('  ·  ', style: style.copyWith(color: c.textTertiary)),
        if (presence != null) ...[
          Container(
            width: s.md,
            height: s.md,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          SizedBox(width: s.sm),
          Text(
            chatPresenceLabel(context, presence),
            style: style.copyWith(color: dot),
          ),
        ],
      ],
    );
  }
}
