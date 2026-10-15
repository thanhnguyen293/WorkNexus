import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_radii.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// A settings card that folds away: [icon], [title] and a one-line [summary]
/// of what is in force, opening on a tap into its [sections] (usually
/// [AppExpandableCardSection]s, split by hairlines).
class AppExpandableCard extends StatefulWidget {
  const AppExpandableCard({
    super.key,
    required this.icon,
    required this.title,
    required this.summary,
    required this.sections,
    this.initiallyExpanded = false,
  });

  final IconData icon;
  final String title;
  final String summary;
  final List<Widget> sections;
  final bool initiallyExpanded;

  @override
  State<AppExpandableCard> createState() => _AppExpandableCardState();
}

class _AppExpandableCardState extends State<AppExpandableCard> {
  late var _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // A Material, not a filled Container, so the header's InkWell hover
    // paints on top of the card's fill.
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.radii.lg),
        side: BorderSide(color: c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(
            icon: widget.icon,
            title: widget.title,
            summary: widget.summary,
            expanded: _expanded,
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          AnimatedSize(
            duration: AppMotion.base,
            curve: AppMotion.enter,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: widget.sections,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.icon,
    required this.title,
    required this.summary,
    required this.expanded,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String summary;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      mouseCursor: WidgetStateMouseCursor.clickable,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.all(context.spacing.xl2),
        child: Row(
          children: [
            Icon(icon, size: context.sizes.iconLg, color: c.accent),
            SizedBox(width: context.spacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.typography.titleLg.copyWith(
                      color: c.textPrimary,
                    ),
                  ),
                  SizedBox(height: context.spacing.xs),
                  Text(
                    summary,
                    style: context.typography.paragraph.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedRotation(
              turns: expanded ? 0.5 : 0,
              duration: AppMotion.base,
              child: Icon(
                LucideIcons.chevronDown300,
                size: context.sizes.iconMd,
                color: c.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A titled block inside an [AppExpandableCard]: [trailing] sits beside the
/// title (a short control), [child] below it (a form, a list).
class AppExpandableCardSection extends StatelessWidget {
  const AppExpandableCardSection({
    super.key,
    required this.title,
    required this.hint,
    this.trailing,
    this.child,
  });

  final String title;
  final String hint;
  final Widget? trailing;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final child = this.child;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.spacing.xl2),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: context.typography.bodyStrong.copyWith(
                    color: c.textPrimary,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          SizedBox(height: context.spacing.xs),
          Text(
            hint,
            style: context.typography.caption.copyWith(color: c.textTertiary),
          ),
          if (child != null) ...[SizedBox(height: context.spacing.lg), child],
        ],
      ),
    );
  }
}
