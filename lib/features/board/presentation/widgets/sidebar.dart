import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import 'settings_nav.dart';
import 'workspace_tree_section.dart';

/// The left navigation rail: the workspace → ZenTao → projects tree and the
/// settings toggle. Fills the width its parent gives it — the drag-to-resize
/// width is owned by [ResizableSidebar] in the app shell.
class SidebarView extends ConsumerWidget {
  const SidebarView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(right: context.hairlineSide),
      ),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                context.spacing.md,
                context.spacing.xl,
                context.spacing.md,
                context.spacing.lg,
              ),
              child: const WorkspaceTreeSection(),
            ),
          ),
          const SettingsNav(),
        ],
      ),
    );
  }
}
