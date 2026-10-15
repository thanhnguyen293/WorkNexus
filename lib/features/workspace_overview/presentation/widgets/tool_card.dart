import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/tools/tool_module.dart';
import '../../../../core/tools/tool_registry_provider.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/badges.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../l10n/app_localizations.dart';
import 'tool_card_metrics.dart';

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
    final r = context.radii;
    final l = AppL10n.of(context);
    final registry = ref.watch(toolRegistryProvider);
    final module = registry[account.providerType];

    if (module == null) return const SizedBox.shrink();

    final role = module.roleLabel(l);
    final subtitle = role.isNotEmpty
        ? '${account.handle} · $role'
        : account.handle;

    return Container(
      constraints: const BoxConstraints(minWidth: 260),
      padding: EdgeInsets.all(s.xl),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(r.lg),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ProviderBadge(account.providerType, big: true),
              SizedBox(width: s.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.providerType.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.typography.bodyStrong.copyWith(
                        color: c.textPrimary,
                      ),
                    ),
                    SizedBox(height: s.xxs),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.typography.captionSm.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: s.lg),
          Divider(height: 1, color: c.border),
          SizedBox(height: s.lg),
          ToolCardMetrics(module: module, account: account),
          SizedBox(height: s.lg),
          _SectionChips(
            account: account,
            module: module,
            sections: module.sections,
          ),
          SizedBox(height: s.lg),
          SizedBox(
            width: double.infinity,
            child: AppButton.filledNeutral(
              onPressed: () => ref
                  .read(appNavProvider.notifier)
                  .selectAccount(account.id, module: module),
              child: Text(l.openToolAction(account.providerType.displayName)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionChips extends ConsumerWidget {
  const _SectionChips({
    required this.account,
    required this.module,
    required this.sections,
  });

  final Account account;
  final ToolModule module;
  final List<ToolSection> sections;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spacing;
    final l = AppL10n.of(context);

    return Wrap(
      spacing: s.xs,
      runSpacing: s.xs,
      children: [
        for (final sec in sections)
          _SectionChip(
            label: sec.label(l),
            onTap: () {
              final navNotifier = ref.read(appNavProvider.notifier);
              navNotifier.selectAccount(account.id, module: module);
              navNotifier.selectSection(sec.id, module: module);
            },
          ),
      ],
    );
  }
}

class _SectionChip extends StatelessWidget {
  const _SectionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final r = context.radii;

    return HoverSurface(
      onTap: onTap,
      borderRadius: BorderRadius.circular(r.sm),
      color: c.surfaceSubtle,
      padding: EdgeInsets.symmetric(horizontal: s.sm, vertical: s.xs),
      child: Text(
        label,
        style: context.typography.captionSm.copyWith(
          color: c.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
