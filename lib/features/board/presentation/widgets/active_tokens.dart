import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/semantic.dart';
import '../../../../core/util/labels.dart';
import '../../../../core/util/zentao_labels.dart';
import '../../../../l10n/app_localizations.dart';
import '../board_providers.dart';

/// Removable chips for each active filter (provider/account/project/status/…).
class ActiveTokens extends ConsumerWidget {
  const ActiveTokens({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final f = ref.watch(filterStateProvider);
    final ctrl = ref.read(filterStateProvider.notifier);
    final lookups = ref.watch(lookupsProvider);

    final tokens = <Widget>[
      for (final p in f.providers)
        _Token(label: p.displayName, onRemove: () => ctrl.toggleProvider(p)),
      for (final a in f.accountIds)
        _Token(
          label: lookups.accounts[a]?.handle ?? a,
          dotColor:
              switch (lookups.workspaces[lookups.accounts[a]?.workspaceId]) {
                final ws? => Color(ws.colorValue),
                null => c.workspaceFallback,
              },
          onRemove: () => ctrl.toggleAccount(a),
        ),
      for (final p in f.projectIds)
        _Token(
          label: lookups.projects[p]?.name ?? p,
          onRemove: () => ctrl.toggleProject(p),
        ),
      for (final s in f.statuses)
        _Token(label: statusLabel(l, s), onRemove: () => ctrl.toggleStatus(s)),
      for (final p in f.priorities)
        _Token(
          label: priorityName(l, p),
          onRemove: () => ctrl.togglePriority(p),
        ),
      for (final s in f.severities)
        _Token(
          label: zentaoSeverityLabel(s) ?? '$s',
          dotColor: severityColor(c, s),
          onRemove: () => ctrl.toggleSeverity(s),
        ),
      for (final a in f.assignees)
        _Token(
          label: a.isEmpty ? l.unassigned : a,
          onRemove: () => ctrl.toggleAssignee(a),
        ),
      for (final t in f.bugTypes)
        _Token(
          label: zentaoBugTypeLabel(t) ?? t,
          onRemove: () => ctrl.toggleBugType(t),
        ),
      for (final r in f.resolutions)
        _Token(
          label: zentaoResolutionLabel(r) ?? r,
          onRemove: () => ctrl.toggleResolution(r),
        ),
      if (f.assignedToMe)
        _Token(label: l.assignedToMe, onRemove: ctrl.toggleAssignedToMe),
      if (f.resolvedByMe)
        _Token(label: l.resolvedByMe, onRemove: ctrl.toggleResolvedByMe),
    ];

    if (tokens.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: context.spacing.sm,
      runSpacing: context.spacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ...tokens,
        GestureDetector(
          onTap: ctrl.clearAll,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: context.spacing.md),
            child: Text(
              l.clear,
              style: context.typography.caption.copyWith(color: c.textTertiary),
            ),
          ),
        ),
      ],
    );
  }
}

class _Token extends StatelessWidget {
  const _Token({required this.label, required this.onRemove, this.dotColor});
  final String label;
  final VoidCallback onRemove;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onRemove,
      child: Container(
        height: 24,
        padding: EdgeInsets.symmetric(horizontal: context.spacing.md),
        decoration: BoxDecoration(
          color: c.selectionFill,
          borderRadius: BorderRadius.circular(context.radii.sm),
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
                  borderRadius: BorderRadius.circular(context.radii.dot),
                ),
              ),
              SizedBox(width: context.spacing.xs),
            ],
            Text(
              label,
              style: context.typography.caption.copyWith(
                color: c.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(width: context.spacing.xs),
            Text(
              '✕',
              style: context.typography.caption.copyWith(color: c.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}
