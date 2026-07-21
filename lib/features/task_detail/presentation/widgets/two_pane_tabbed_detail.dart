import 'package:flutter/material.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';

/// Below this panel width the overview content + metadata sidebar stack
/// vertically; above it they sit side by side.
const double kTwoPaneBreakpoint = 820;

/// The shared shell for a merge-request / pull-request two-pane detail: a fixed
/// header, a tab strip (Overview · Commits · Changed files), then the tab body.
///
/// The Overview tab lays [overviewSections] beside [sidebar] (stacked when
/// narrow); the Commits / Changes tabs render [commits] / [changes] full-width.
/// Keeping the code-review sections behind their own tabs mirrors the GitLab /
/// GitHub web layout and keeps the overview focused on the conversation.
class TwoPaneTabbedDetail extends StatefulWidget {
  const TwoPaneTabbedDetail({
    super.key,
    required this.header,
    required this.isSyncing,
    required this.overviewSections,
    required this.sidebar,
    required this.commits,
    required this.changes,
  });

  final Widget header;
  final bool isSyncing;

  /// The Overview content column (description → merge widget → activity).
  final List<Widget> overviewSections;

  /// The metadata sidebar shown on the Overview tab.
  final Widget sidebar;
  final Widget commits;
  final Widget changes;

  @override
  State<TwoPaneTabbedDetail> createState() => _TwoPaneTabbedDetailState();
}

enum _DetailPaneTab { overview, commits, changes }

class _TwoPaneTabbedDetailState extends State<TwoPaneTabbedDetail> {
  _DetailPaneTab _tab = _DetailPaneTab.overview;

  /// Tabs the user has opened at least once. An [IndexedStack] keeps every
  /// visited tab alive, so switching away and back preserves its state (loaded
  /// commits / diffs, expanded rows, scroll position). Unvisited tabs render
  /// nothing so their loaders stay lazy until first opened.
  final Set<_DetailPaneTab> _visited = {_DetailPaneTab.overview};

  void _select(_DetailPaneTab tab) => setState(() {
    _tab = tab;
    _visited.add(tab);
  });

  Widget _lazy(_DetailPaneTab tab, Widget child) =>
      _visited.contains(tab) ? child : const SizedBox.shrink();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.card,
      child: Column(
        children: [
          widget.header,
          if (widget.isSyncing)
            LinearProgressIndicator(
              minHeight: context.borders.thick,
              backgroundColor: Colors.transparent,
              color: c.accent,
            )
          else
            SizedBox(height: context.borders.hairline),
          _PaneTabs(current: _tab, onSelect: _select),
          Expanded(
            child: IndexedStack(
              sizing: StackFit.expand,
              index: _tab.index,
              children: [
                _lazy(
                  _DetailPaneTab.overview,
                  _OverviewBody(
                    sections: widget.overviewSections,
                    sidebar: widget.sidebar,
                  ),
                ),
                _lazy(
                  _DetailPaneTab.commits,
                  _ScrollBody(child: widget.commits),
                ),
                _lazy(
                  _DetailPaneTab.changes,
                  _ScrollBody(child: widget.changes),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The Overview tab: content column beside the sidebar (stacked when narrow).
class _OverviewBody extends StatelessWidget {
  const _OverviewBody({required this.sections, required this.sidebar});

  final List<Widget> sections;
  final Widget sidebar;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < kTwoPaneBreakpoint;
        // Fixed metadata-pane width in the wide layout (six of the base step).
        final sidebarWidth = context.spacing.xl6 * 6;
        return _ScrollBody(
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...sections,
                    SizedBox(height: context.spacing.xl2),
                    sidebar,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: sections,
                      ),
                    ),
                    SizedBox(width: context.spacing.xl3),
                    SizedBox(width: sidebarWidth, child: sidebar),
                  ],
                ),
        );
      },
    );
  }
}

class _ScrollBody extends StatelessWidget {
  const _ScrollBody({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        context.spacing.xl3,
        context.spacing.xl2,
        context.spacing.xl3,
        context.spacing.xl3,
      ),
      child: child,
    );
  }
}

/// The two-pane detail's tab strip, matching the standard panel's [DetailTabBar]
/// styling (accent underline on the active tab).
class _PaneTabs extends StatelessWidget {
  const _PaneTabs({required this.current, required this.onSelect});

  final _DetailPaneTab current;
  final ValueChanged<_DetailPaneTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final labels = {
      _DetailPaneTab.overview: l.overview,
      _DetailPaneTab.commits: l.commits,
      _DetailPaneTab.changes: l.changedFiles,
    };
    return Container(
      decoration: BoxDecoration(border: Border(bottom: context.hairlineSide)),
      padding: EdgeInsets.symmetric(horizontal: context.spacing.xl),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final e in labels.entries)
              _PaneTab(
                label: e.value,
                selected: e.key == current,
                onTap: () => onSelect(e.key),
              ),
          ],
        ),
      ),
    );
  }
}

class _PaneTab extends StatelessWidget {
  const _PaneTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: context.spacing.xl6,
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(horizontal: context.spacing.xl),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? c.accent : Colors.transparent,
              width: context.borders.thick,
            ),
          ),
        ),
        child: Text(
          label,
          style: context.typography.secondary.copyWith(
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? c.textPrimary : c.textSecondary,
          ),
        ),
      ),
    );
  }
}
