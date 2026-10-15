import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/hover_surface.dart';
import '../../l10n/app_localizations.dart';
import 'scope_rows.dart';

/// The scrollable body of a tool navigation pane (L4 scope list).
/// Organizes quick scopes, pinned scopes, recent scopes, and all scopes
/// with a 12-item cap and an expandable "Show all…" trigger (design §4 / S4.3).
class ScopeListBody extends StatefulWidget {
  const ScopeListBody({
    super.key,
    this.quickScopeRows = const [],
    this.pinnedRows = const [],
    this.recentRows = const [],
    this.allRows = const [],
    this.groupTitle,
    this.cap = 12,
    this.showAllLabel,
    this.initiallyExpanded = false,
    this.emptyPlaceholder,
    this.padding,
  });

  final List<Widget> quickScopeRows;
  final List<Widget> pinnedRows;
  final List<Widget> recentRows;
  final List<Widget> allRows;
  final String? groupTitle;
  final int cap;
  final String? showAllLabel;
  final bool initiallyExpanded;
  final Widget? emptyPlaceholder;
  final EdgeInsetsGeometry? padding;

  @override
  State<ScopeListBody> createState() => _ScopeListBodyState();
}

class _ScopeListBodyState extends State<ScopeListBody> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  void _onExpand() {
    setState(() => _expanded = true);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final s = context.spacing;

    final isEmpty =
        widget.quickScopeRows.isEmpty &&
        widget.pinnedRows.isEmpty &&
        widget.recentRows.isEmpty &&
        widget.allRows.isEmpty;

    if (isEmpty && widget.emptyPlaceholder != null) {
      return Center(child: widget.emptyPlaceholder!);
    }

    final hasCap = !_expanded && widget.allRows.length > widget.cap;
    final visibleAllRows = hasCap
        ? widget.allRows.take(widget.cap).toList()
        : widget.allRows;

    return ListView(
      padding: widget.padding ?? EdgeInsets.fromLTRB(s.sm, s.xs, s.sm, s.lg),
      children: [
        // Quick scopes (All, Assigned to me, Review requested)
        if (widget.quickScopeRows.isNotEmpty) ...[
          ...widget.quickScopeRows,
          SizedBox(height: s.xs),
        ],

        // Pinned scopes
        if (widget.pinnedRows.isNotEmpty) ...[
          ScopeGroupHeader(title: l.pinned),
          ...widget.pinnedRows,
          SizedBox(height: s.xs),
        ],

        // Recent scopes (max 5)
        if (widget.recentRows.isNotEmpty) ...[
          ScopeGroupHeader(title: l.recent),
          ...widget.recentRows,
          SizedBox(height: s.xs),
        ],

        // All scopes (with cap)
        if (widget.allRows.isNotEmpty) ...[
          if (widget.groupTitle != null)
            ScopeGroupHeader(title: widget.groupTitle!),
          ...visibleAllRows,
          if (hasCap)
            ShowAllScopesButton(
              label: widget.showAllLabel ?? l.showAll,
              onTap: _onExpand,
            ),
        ],
      ],
    );
  }
}

/// The "Show all {n}…" expander button displayed when rows exceed the cap.
class ShowAllScopesButton extends StatelessWidget {
  const ShowAllScopesButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;

    return HoverSurface(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.radii.sm),
      color: Colors.transparent,
      padding: EdgeInsets.symmetric(horizontal: s.sm, vertical: s.xxs),
      height: context.sizes.controlSm,
      child: Row(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.typography.bodySm.copyWith(
              color: c.accent,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
