import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/value_objects/priority.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/domain/value_objects/unified_status.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/semantic.dart';
import '../../../../core/util/labels.dart';
import '../../../../l10n/app_localizations.dart';
import '../board_providers.dart';

/// The advanced-filter dropdown: chip groups for provider/account/project/
/// status/priority.
class FilterPopover extends ConsumerWidget {
  const FilterPopover({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final f = ref.watch(filterStateProvider);
    final ctrl = ref.read(filterStateProvider.notifier);
    final lookups = ref.watch(lookupsProvider);

    return Container(
      width: 340,
      constraints: const BoxConstraints(maxHeight: 500),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(context.radii.lg),
        border: Border.all(color: c.borderStrong),
        boxShadow: [
          BoxShadow(
            color: c.scrim.withValues(alpha: 0.22),
            blurRadius: 40,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        context.spacing.xl2,
        context.spacing.xl,
        context.spacing.xl2,
        context.spacing.xl2,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Group(
              label: l.provider,
              children: [
                for (final p in ProviderType.values)
                  _Chip(
                    label: p.displayName,
                    active: f.providers.contains(p),
                    onTap: () => ctrl.toggleProvider(p),
                  ),
              ],
            ),
            _Group(
              label: l.account,
              children: [
                for (final a in lookups.accounts.values)
                  _Chip(
                    label: a.handle,
                    active: f.accountIds.contains(a.id),
                    dotColor: switch (lookups.workspaces[a.workspaceId]) {
                      final ws? => Color(ws.colorValue),
                      null => c.workspaceFallback,
                    },
                    onTap: () => ctrl.toggleAccount(a.id),
                  ),
              ],
            ),
            _Group(
              label: l.project,
              children: [
                for (final p in lookups.projects.values)
                  _Chip(
                    label: p.name,
                    active: f.projectIds.contains(p.id),
                    onTap: () => ctrl.toggleProject(p.id),
                  ),
              ],
            ),
            _Group(
              label: l.status,
              children: [
                for (final s in UnifiedStatus.columns)
                  _Chip(
                    label: statusLabel(l, s),
                    active: f.statuses.contains(s),
                    dotColor: statusColor(c, s),
                    onTap: () => ctrl.toggleStatus(s),
                  ),
              ],
            ),
            _Group(
              label: l.priority,
              children: [
                for (final p in Priority.values)
                  _Chip(
                    label: priorityName(l, p),
                    active: f.priorities.contains(p),
                    dotColor: priorityColor(c, p),
                    onTap: () => ctrl.togglePriority(p),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.label, required this.children});
  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: context.typography.label.copyWith(
              color: context.colors.textTertiary,
            ),
          ),
          SizedBox(height: context.spacing.sm),
          Wrap(
            spacing: context.spacing.sm,
            runSpacing: context.spacing.sm,
            children: children,
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.active,
    required this.onTap,
    this.dotColor,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 26,
        padding: EdgeInsets.symmetric(horizontal: context.spacing.lg),
        decoration: BoxDecoration(
          color: active ? c.selectionFill : c.surfaceSubtle,
          borderRadius: BorderRadius.circular(context.radii.pill),
          border: context.borders.showOutline
              ? Border.all(color: c.border)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: context.spacing.xs),
            ],
            Text(
              label,
              style: context.typography.meta.copyWith(
                fontWeight: FontWeight.w500,
                color: active ? c.textPrimary : c.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
