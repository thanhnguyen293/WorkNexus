import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_section_header.dart';
import '../../../../core/widgets/badges.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../l10n/app_localizations.dart';

/// One titled block of the profile popup: an uppercase label over a softly
/// filled card of rows.
class ChatProfileSection extends StatelessWidget {
  const ChatProfileSection({
    super.key,
    required this.title,
    required this.children,
    this.count,
  });

  final String title;
  final int? count;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    return Padding(
      padding: EdgeInsets.only(top: s.xl3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSectionHeader(
            title: title,
            count: count,
            padding: EdgeInsets.only(left: s.xs, bottom: s.xs),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: c.surfaceSubtle,
              borderRadius: BorderRadius.circular(context.radii.md),
              border: Border.all(color: c.border),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: s.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Placeholder rows while a section's data is fetched.
class ChatProfileLoadingRows extends StatelessWidget {
  const ChatProfileLoadingRows({super.key, this.rows = 2});

  final int rows;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    return Column(
      children: [
        for (var i = 0; i < rows; i++)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: s.xl, vertical: s.md),
            child: Row(
              children: [
                SkeletonBox(
                  width: s.xl5,
                  height: s.xl5,
                  radius: context.radii.sm,
                ),
                SizedBox(width: s.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: s.xl6 * 1.5, height: s.md),
                      SizedBox(height: s.sm),
                      SkeletonBox(height: s.lg),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A quiet one-line note inside a section (a failed fetch, "+3 more").
class ChatProfileNote extends StatelessWidget {
  const ChatProfileNote(this.text, {super.key, this.isError = false});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: s.xl, vertical: s.md),
      child: Text(
        text,
        style: context.typography.caption.copyWith(
          color: isError ? c.error : c.textTertiary,
        ),
      ),
    );
  }
}

/// The first [shown] of [rows], then a "+N more" row that reveals the rest
/// (and "Show less" to fold them back).
class ChatProfileExpandableRows extends StatefulWidget {
  const ChatProfileExpandableRows({
    super.key,
    required this.rows,
    required this.shown,
  });

  final List<Widget> rows;
  final int shown;

  @override
  State<ChatProfileExpandableRows> createState() =>
      _ChatProfileExpandableRowsState();
}

class _ChatProfileExpandableRowsState extends State<ChatProfileExpandableRows> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final rows = widget.rows;
    final hidden = rows.length - widget.shown;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...(_expanded ? rows : rows.take(widget.shown)),
        if (hidden > 0)
          _ToggleRow(
            label: _expanded
                ? l.chatProfileShowLess
                : l.chatProfileMore(hidden),
            expanded: _expanded,
            onTap: () => setState(() => _expanded = !_expanded),
          ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.expanded,
    required this.onTap,
  });

  final String label;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    return HoverSurface(
      onTap: onTap,
      semanticLabel: label,
      padding: EdgeInsets.symmetric(horizontal: s.xl, vertical: s.md),
      child: Row(
        children: [
          Text(
            label,
            style: context.typography.captionStrong.copyWith(color: c.accent),
          ),
          SizedBox(width: s.xs),
          Icon(
            expanded ? LucideIcons.chevronUp300 : LucideIcons.chevronDown300,
            size: context.sizes.iconSm,
            color: c.accent,
          ),
        ],
      ),
    );
  }
}
