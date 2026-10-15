import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/domain/entities/account.dart';
import '../../core/navigation/navigation_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/tools/tool_module.dart';
import '../../core/tools/tool_registry_provider.dart';
import '../../core/widgets/hover_surface.dart';
import '../../l10n/app_localizations.dart';
import 'workspace_breadcrumb_trigger.dart';
import 'workspace_switcher_popover.dart';

/// The contextual navigation breadcrumb on the left side of the title bar
/// (design §2, specs S2.1): `[badge] Workspace ▾ / Tool / Section / Scope`.
class WorkspaceBreadcrumb extends ConsumerStatefulWidget {
  const WorkspaceBreadcrumb({super.key});

  @override
  ConsumerState<WorkspaceBreadcrumb> createState() =>
      _WorkspaceBreadcrumbState();
}

class _WorkspaceBreadcrumbState extends ConsumerState<WorkspaceBreadcrumb> {
  final MenuController _menuController = MenuController();

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final l = AppL10n.of(context);
    final activeWs = ref.watch(activeWorkspaceProvider);
    final nav = ref.watch(appNavProvider);
    final accounts = ref.watch(accountsProvider).asData?.value ?? const [];
    final registry = ref.watch(toolRegistryProvider);

    if (activeWs == null) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MenuAnchor(
          controller: _menuController,
          alignmentOffset: Offset(0, s.xs),
          style: const MenuStyle(
            backgroundColor: WidgetStatePropertyAll(Colors.transparent),
            shadowColor: WidgetStatePropertyAll(Colors.transparent),
            elevation: WidgetStatePropertyAll(0),
            padding: WidgetStatePropertyAll(EdgeInsets.zero),
          ),
          menuChildren: [
            WorkspaceSwitcherPopover(onClose: _menuController.close),
          ],
          builder: (context, controller, child) {
            return WorkspaceBreadcrumbTrigger(
              workspace: activeWs,
              isOpen: controller.isOpen,
              onTap: () =>
                  controller.isOpen ? controller.close() : controller.open(),
            );
          },
        ),
        ...switch (nav.rail) {
          WorkspaceTarget() => _buildWorkspaceSegments(context, nav, l),
          AccountTarget(:final accountId) => _buildAccountSegments(
            context,
            ref,
            accountId,
            accounts,
            registry,
            nav,
            l,
          ),
        },
      ],
    );
  }

  List<Widget> _buildWorkspaceSegments(
    BuildContext context,
    AppNavState nav,
    AppL10n l,
  ) {
    final c = context.colors;
    final label = switch (nav.workspaceSection) {
      WorkspaceSection.overview => l.overview,
      WorkspaceSection.integrations => l.integrations,
      WorkspaceSection.members => l.members,
      WorkspaceSection.settings => l.settings,
    };

    return [
      _Separator(color: c.textTertiary),
      Text(
        label,
        style: context.typography.bodySmStrong.copyWith(color: c.textPrimary),
      ),
    ];
  }

  List<Widget> _buildAccountSegments(
    BuildContext context,
    WidgetRef ref,
    String accountId,
    List<Account> accounts,
    Map<dynamic, ToolModule> registry,
    AppNavState nav,
    AppL10n l,
  ) {
    final c = context.colors;
    final account = accounts.where((a) => a.id == accountId).firstOrNull;
    if (account == null) return const [];

    final module = registry[account.providerType];
    if (module == null) return const [];

    final hasMultiple =
        accounts.where((a) => a.providerType == account.providerType).length >
        1;
    final toolLabel = hasMultiple
        ? account.handle
        : account.providerType.displayName;

    final loc = nav.locations[accountId];
    final activeSectionId = loc?.section ?? module.defaultSection;
    final sec = module.sections
        .where((s) => s.id == activeSectionId)
        .firstOrNull;
    final sectionLabel = sec?.label(l) ?? activeSectionId.value;

    final scopeId = loc?.scopeId;
    final hasScope = scopeId != null && scopeId.isNotEmpty;

    final widgets = <Widget>[
      _Separator(color: c.textTertiary),
      _BreadcrumbLink(
        label: toolLabel,
        isLast: false,
        onTap: () {
          ref
              .read(appNavProvider.notifier)
              .selectAccount(account.id, module: module);
        },
      ),
      _Separator(color: c.textTertiary),
      _BreadcrumbLink(
        label: sectionLabel,
        isLast: !hasScope,
        onTap: hasScope
            ? () {
                ref.read(appNavProvider.notifier).selectScope(null);
              }
            : null,
      ),
    ];

    if (hasScope) {
      widgets.addAll([
        _Separator(color: c.textTertiary),
        Text(
          scopeId,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.typography.bodySmStrong.copyWith(color: c.textPrimary),
        ),
      ]);
    }

    return widgets;
  }
}

class _Separator extends StatelessWidget {
  const _Separator({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: s.xs),
      child: Text(
        '/',
        style: context.typography.captionSm.copyWith(color: color),
      ),
    );
  }
}

class _BreadcrumbLink extends StatelessWidget {
  const _BreadcrumbLink({
    required this.label,
    required this.isLast,
    this.onTap,
  });

  final String label;
  final bool isLast;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final r = context.radii;

    if (isLast || onTap == null) {
      return Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.typography.bodySmStrong.copyWith(color: c.textPrimary),
      );
    }

    return HoverSurface(
      onTap: onTap!,
      borderRadius: BorderRadius.circular(r.sm),
      padding: EdgeInsets.symmetric(horizontal: s.xs, vertical: s.none),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.typography.bodySm.copyWith(color: c.textSecondary),
      ),
    );
  }
}
