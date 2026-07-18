import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import 'settings_nav.dart';
import 'workspace_tree_section.dart';

/// The left navigation rail: the workspace → ZenTao → projects tree and the
/// settings toggle.
class SidebarView extends ConsumerWidget {
  const SidebarView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return Container(
      width: 290,
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
