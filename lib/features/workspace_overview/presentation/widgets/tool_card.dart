import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/tools/tool_registry_provider.dart';
import 'tool_card_metrics.dart';
import 'tool_card_parts.dart';

/// A tool account card for the Workspace Overview grid (design §5, specs S6.1).
/// Width is at least 260px. Shows account info, role, 2 metrics, section chips,
/// and an "Open {Tool} →" action.
class ToolCard extends ConsumerWidget {
  const ToolCard({super.key, required this.account});

  final Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final module = ref.watch(toolRegistryProvider)[account.providerType];
    if (module == null) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(minWidth: 260),
      padding: EdgeInsets.all(s.xl),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(context.radii.lg),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ToolCardIdentity(account: account, module: module),
          SizedBox(height: s.lg),
          Divider(height: 1, color: c.border),
          SizedBox(height: s.lg),
          ToolCardMetrics(module: module, account: account),
          SizedBox(height: s.lg),
          ToolSectionChips(account: account, module: module),
          SizedBox(height: s.lg),
          SizedBox(
            width: double.infinity,
            child: ToolOpenButton(account: account, module: module),
          ),
        ],
      ),
    );
  }
}
