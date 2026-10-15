import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/app_segmented_tabs.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/mini_app_permission.dart';
import '../providers/mini_app_providers.dart';
import '../util/mini_app_permission_kind.dart';

/// The edit dialog's list of what the user allowed or blocked for this mini
/// app: flip an answer, or have the page asked again.
class MiniAppPermissionsSection extends ConsumerWidget {
  const MiniAppPermissionsSection({super.key, required this.miniAppId});

  final String miniAppId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final grants =
        ref.watch(miniAppPermissionsProvider(miniAppId)).asData?.value ??
        const <MiniAppPermissionGrant>[];
    final sorted = [...grants]
      ..sort((a, b) => a.kind.index.compareTo(b.kind.index));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: s.sm,
      children: [
        Text(
          l.miniAppPermissionsTitle,
          style: context.typography.captionStrong.copyWith(
            color: c.textSecondary,
          ),
        ),
        if (sorted.isEmpty)
          Text(
            l.miniAppPermissionsEmpty,
            style: context.typography.caption.copyWith(color: c.textTertiary),
          )
        else
          for (final grant in sorted)
            _PermissionRow(miniAppId: miniAppId, grant: grant),
      ],
    );
  }
}

class _PermissionRow extends ConsumerWidget {
  const _PermissionRow({required this.miniAppId, required this.grant});

  final String miniAppId;
  final MiniAppPermissionGrant grant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final controller = ref.read(miniAppPermissionControllerProvider.notifier);
    final allowed = grant.decision == MiniAppPermissionDecision.allow;
    Future<void> report(Future<Result<void>> change) async {
      if ((await change).isErr && context.mounted) {
        showAppSnack(context, l.miniAppPermissionSaveFailed, isError: true);
      }
    }

    void set(MiniAppPermissionDecision decision) =>
        report(controller.remember(miniAppId, [grant.kind], decision));
    return Row(
      spacing: s.md,
      children: [
        Icon(
          grant.kind.icon,
          size: context.sizes.iconMd,
          color: c.textSecondary,
        ),
        Expanded(
          child: Text(
            grant.kind.label(l),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.typography.body.copyWith(color: c.textPrimary),
          ),
        ),
        AppSegmentedTabs(
          tabs: [
            AppSegmentedTab(
              label: l.miniAppPermissionAllowed,
              active: allowed,
              onTap: () => set(MiniAppPermissionDecision.allow),
            ),
            AppSegmentedTab(
              label: l.miniAppPermissionBlocked,
              active: !allowed,
              onTap: () => set(MiniAppPermissionDecision.block),
            ),
          ],
        ),
        AppIconButton(
          icon: LucideIcons.rotateCcw300,
          tooltip: l.miniAppPermissionReset,
          onPressed: () => report(controller.forget(miniAppId, grant.kind)),
        ),
      ],
    );
  }
}
