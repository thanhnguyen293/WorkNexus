import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../util/activity_action_parts.dart';

/// Width of the timeline's left gutter — the avatar / event-icon column the
/// rail runs through.
const double kTimelineGutter = 24;

/// One entry of the comments & activity timeline: a marker in the left gutter
/// (the author's avatar for a comment, a small icon for an event) on a rail
/// that runs unbroken from the first entry to the last, and [child] beside it.
class TimelineItem extends StatelessWidget {
  const TimelineItem({
    super.key,
    required this.marker,
    required this.isFirst,
    required this.isLast,
    required this.child,
  });

  final Widget marker;
  final bool isFirst;
  final bool isLast;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    return Stack(
      children: [
        // The rail stops at the first / last marker's center so it never
        // dangles past the ends of the timeline.
        if (!(isFirst && isLast))
          Positioned(
            left: kTimelineGutter / 2,
            top: isFirst ? kTimelineGutter / 2 : 0,
            bottom: isLast ? null : 0,
            height: isLast ? kTimelineGutter / 2 : null,
            child: Container(width: 1, color: context.colors.border),
          ),
        Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : s.xl),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: kTimelineGutter,
                height: kTimelineGutter,
                child: Center(child: marker),
              ),
              SizedBox(width: s.lg),
              Expanded(child: child),
            ],
          ),
        ),
      ],
    );
  }
}

/// A comment's marker: its author's avatar, on an opaque ring so the rail
/// passes behind it.
class TimelineAvatar extends StatelessWidget {
  const TimelineAvatar(this.name, {super.key});
  final String name;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.colors.card,
      shape: BoxShape.circle,
    ),
    child: UserAvatar(name: name, diameter: kTimelineGutter),
  );
}

/// An event's marker: a small icon for what it did, in a ring that masks the
/// rail.
class TimelineEventIcon extends StatelessWidget {
  const TimelineEventIcon(this.kind, {super.key});
  final ActivityKind kind;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (icon, color) = switch (kind) {
      ActivityKind.created => (PhosphorIconsLight.plus, c.textSecondary),
      ActivityKind.assigned => (PhosphorIconsLight.user, c.textSecondary),
      ActivityKind.edited => (PhosphorIconsLight.pencilSimple, c.textSecondary),
      ActivityKind.resolved => (PhosphorIconsLight.check, c.success),
      ActivityKind.reopened => (
        PhosphorIconsLight.arrowCounterClockwise,
        c.warning,
      ),
      ActivityKind.confirmed => (PhosphorIconsLight.sealCheck, c.accent),
      ActivityKind.closed => (PhosphorIconsLight.x, c.textSecondary),
      ActivityKind.other => (PhosphorIconsLight.dotOutline, c.textTertiary),
    };
    const side = kTimelineGutter * 0.8;
    return Container(
      width: side,
      height: side,
      decoration: BoxDecoration(
        color: c.card,
        shape: BoxShape.circle,
        border: Border.all(color: c.border),
      ),
      child: Icon(icon, size: side * 0.6, color: color),
    );
  }
}
