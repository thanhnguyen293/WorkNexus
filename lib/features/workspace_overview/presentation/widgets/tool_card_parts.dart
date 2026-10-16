import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/tools/tool_module.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/badges.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../l10n/app_localizations.dart';

/// The pieces of a tool account's Overview card, shared by the compact
/// [ToolCard] and the full-width ZenTao section.

/// The tool's badge, its name and "handle · role".
class ToolCardIdentity extends StatelessWidget {
  const ToolCardIdentity({
    super.key,
    required this.account,
    required this.module,
  });

  final Account account;
  final ToolModule module;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final role = module.roleLabel(AppL10n.of(context));
    final subtitle = role.isNotEmpty
        ? '${account.handle} · $role'
        : account.handle;
    return Row(
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
    );
  }
}

/// "Open {Tool} →": the account in its tool.
class ToolOpenButton extends ConsumerWidget {
  const ToolOpenButton({
    super.key,
    required this.account,
    required this.module,
  });

  final Account account;
  final ToolModule module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppButton.filledNeutral(
      onPressed: () => ref
          .read(appNavProvider.notifier)
          .selectAccount(account.id, module: module),
      child: Text(
        AppL10n.of(context).openToolAction(account.providerType.displayName),
      ),
    );
  }
}

/// One chip per tool section, each opening the account in that section.
class ToolSectionChips extends ConsumerWidget {
  const ToolSectionChips({
    super.key,
    required this.account,
    required this.module,
  });

  final Account account;
  final ToolModule module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spacing;
    final l = AppL10n.of(context);

    return Wrap(
      spacing: s.xs,
      runSpacing: s.xs,
      children: [
        for (final sec in module.sections)
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
