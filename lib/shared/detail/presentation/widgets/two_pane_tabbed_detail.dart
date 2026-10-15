import 'package:flutter/material.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import 'detail_underline_tabs.dart';

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
    this.overviewCount,
    this.changesCount,
  });

  final Widget header;
  final bool isSyncing;

  /// The Overview content column (description → merge widget → activity).
  final List<Widget> overviewSections;

  /// The metadata sidebar shown on the Overview tab.
  final Widget sidebar;
  final Widget commits;
  final Widget changes;

  /// Tab counts, where known: the conversation size and the changed files.
  final int? overviewCount;
  final int? changesCount;

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
    final l = AppL10n.of(context);
    return Material(
      color: c.card,
      child: Column(
        children: [
          widget.header,
          // A constant-height slot, so the bar coming and going never shifts
          // the tabs below.
          SizedBox(
            height: context.borders.thick,
            child: widget.isSyncing
                ? LinearProgressIndicator(
                    minHeight: context.borders.thick,
                    backgroundColor: Colors.transparent,
                  )
                : null,
          ),
          DetailUnderlineTabs<_DetailPaneTab>(
            labels: {
              _DetailPaneTab.overview: l.overview,
              _DetailPaneTab.commits: l.commits,
              _DetailPaneTab.changes: l.changedFiles,
            },
            counts: {
              _DetailPaneTab.overview: ?widget.overviewCount,
              _DetailPaneTab.changes: ?widget.changesCount,
            },
            current: _tab,
            onSelect: _select,
          ),
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
