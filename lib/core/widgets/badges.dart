import 'package:flutter/material.dart';

import '../domain/value_objects/priority.dart';
import '../domain/value_objects/provider_type.dart';
import '../domain/value_objects/translation_state.dart';
import '../domain/value_objects/unified_status.dart';
import '../theme/app_borders.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/semantic.dart';

/// Provider code chip (GH/GL/JR/ZT), colored by brand.
class ProviderBadge extends StatelessWidget {
  const ProviderBadge(this.provider, {super.key, this.big = false});
  final ProviderType provider;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final brand = providerBrandColor(provider);
    return Container(
      constraints: BoxConstraints(minWidth: big ? 24 : 20),
      height: big ? 17 : 15,
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: context.spacing.xs),
      decoration: BoxDecoration(
        color: c.mixT(brand, 0.16),
        borderRadius: BorderRadius.circular(context.radii.xs),
        border: context.borders.showOutline
            ? Border.all(color: c.mixT(brand, 0.34))
            : null,
      ),
      child: Text(
        provider.code,
        style: (big ? context.typography.badgeLg : context.typography.badgeSm)
            .copyWith(color: brand),
      ),
    );
  }
}

/// Provider-specific priority tag (P0 / priority::1 / ◆ High / Pri 1).
class PriorityTag extends StatelessWidget {
  const PriorityTag(this.provider, this.priority, {super.key});
  final ProviderType provider;
  final Priority priority;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = priorityColor(c, priority);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.sm,
        vertical: context.spacing.xxs,
      ),
      decoration: BoxDecoration(
        color: c.mixT(color, 0.17),
        borderRadius: BorderRadius.circular(
          priorityRadius(context.radii, provider),
        ),
        border: context.borders.showOutline
            ? Border.all(color: c.mixT(color, 0.44))
            : null,
      ),
      child: Text(
        priorityLabel(provider, priority),
        style: context.typography.badge.copyWith(
          color: color,
        ),
      ),
    );
  }
}

/// Small square workspace badge with its short code.
class WorkspaceBadge extends StatelessWidget {
  const WorkspaceBadge(this.color, this.short, {super.key, this.big = false});
  final Color color;
  final String short;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final s = big ? 18.0 : 16.0;
    return Container(
      width: s,
      height: s,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(context.radii.xs),
      ),
      child: Text(
        short,
        style: (big ? context.typography.badgeLg : context.typography.badge)
            .copyWith(color: context.colors.onColorInk),
      ),
    );
  }
}

/// Workspace/project pill: a dot + label tinted by workspace color.
class WorkspaceTag extends StatelessWidget {
  const WorkspaceTag(this.color, this.label, {super.key});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: EdgeInsets.fromLTRB(
        context.spacing.md,
        context.spacing.xxs,
        context.spacing.md,
        context.spacing.xxs,
      ),
      decoration: BoxDecoration(
        color: c.mixT(color, 0.15),
        borderRadius: BorderRadius.circular(context.radii.sm),
        border: context.borders.showOutline
            ? Border.all(color: c.mixT(color, 0.30))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: context.spacing.xs),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: context.typography.mono.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A tiny labeled pill tinted by [color] — e.g. the Bug/Task kind tag shown on
/// pinned sources-tree rows.
class MiniTag extends StatelessWidget {
  const MiniTag(this.label, this.color, {super.key});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.xs,
        vertical: context.spacing.xxs,
      ),
      decoration: BoxDecoration(
        color: c.mixT(color, 0.16),
        borderRadius: BorderRadius.circular(context.radii.xs),
        border: context.borders.showOutline
            ? Border.all(color: c.mixT(color, 0.40))
            : null,
      ),
      child: Text(
        label,
        style: context.typography.badgeSm.copyWith(color: color),
      ),
    );
  }
}

/// A small status dot.
class StatusDot extends StatelessWidget {
  const StatusDot(this.status, {super.key, this.size = 8});
  final UnifiedStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: statusColor(context.colors, status),
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Translation status colors + short labels (design transInfo).
({Color color, String label, bool fill}) translationVisual(
  AppColors c,
  TranslationState s,
) {
  return switch (s) {
    TranslationState.none => (color: c.textTertiary, label: 'VI', fill: false),
    TranslationState.loading => (color: c.accent, label: 'VI', fill: false),
    TranslationState.done => (color: c.success, label: 'VI ✓', fill: true),
    TranslationState.outdated => (color: c.warning, label: 'VI !', fill: true),
    TranslationState.error => (color: c.error, label: 'VI ✕', fill: true),
  };
}

/// A 7px translation dot for the board card.
class TranslationDot extends StatelessWidget {
  const TranslationDot(this.state, {super.key});
  final TranslationState state;

  @override
  Widget build(BuildContext context) {
    final v = translationVisual(context.colors, state);
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: v.color, shape: BoxShape.circle),
    );
  }
}

/// The VI chip used in the List view's translation column.
class TranslationChip extends StatelessWidget {
  const TranslationChip(this.state, {super.key});
  final TranslationState state;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final v = translationVisual(c, state);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.xs,
        vertical: context.spacing.xxs,
      ),
      decoration: BoxDecoration(
        color: v.fill ? c.mixT(v.color, 0.16) : Colors.transparent,
        borderRadius: BorderRadius.circular(context.radii.xs),
        border: context.borders.showOutline
            ? Border.all(color: c.mixT(v.color, 0.40))
            : null,
      ),
      child: Text(
        v.label,
        style: context.typography.badgeSm.copyWith(color: v.color),
      ),
    );
  }
}

/// A shimmering skeleton block for loading states.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({super.key, this.width, this.height = 12, this.radius = 6});
  final double? width;
  final double height;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1 - 2 * (1 - _c.value), 0),
              end: Alignment(1 + 2 * _c.value, 0),
              colors: [c.skeleton, c.skeletonHighlight, c.skeleton],
              stops: const [0.25, 0.5, 0.75],
            ),
          ),
        );
      },
    );
  }
}
