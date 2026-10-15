import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dialog_frame.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/mini_app_permission.dart';
import '../util/mini_app_permission_kind.dart';

/// Asks whether the page of [site] may use [kinds]: what it wants in the
/// title, what allowing it means under it, and the two answers. Resolves to
/// the answer, or null when dismissed (neither remembered nor allowed).
class MiniAppPermissionDialog extends StatelessWidget {
  const MiniAppPermissionDialog({
    super.key,
    required this.site,
    required this.kinds,
  });

  final String site;
  final List<MiniAppPermissionKind> kinds;

  static Future<MiniAppPermissionDecision?> show(
    BuildContext context, {
    required String site,
    required List<MiniAppPermissionKind> kinds,
  }) => showDialog<MiniAppPermissionDecision>(
    context: context,
    builder: (_) => MiniAppPermissionDialog(site: site, kinds: kinds),
  );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    return AppDialogFrame(
      title: l.miniAppPermissionTitle(
        site,
        kinds.map((k) => k.action(l)).join(', '),
      ),
      leadingIcon: kinds.first.icon,
      maxWidth: context.sizes.dialogSm,
      actions: [
        const Spacer(),
        AppButton.outlinedNeutral(
          size: AppButtonSize.small,
          onPressed: () =>
              Navigator.of(context).pop(MiniAppPermissionDecision.block),
          child: Text(l.miniAppPermissionBlock),
        ),
        AppButton.filled(
          size: AppButtonSize.small,
          onPressed: () =>
              Navigator.of(context).pop(MiniAppPermissionDecision.allow),
          child: Text(l.miniAppPermissionAllow),
        ),
      ],
      child: Padding(
        padding: EdgeInsets.fromLTRB(s.xl3, 0, s.xl3, s.xl3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: s.xl,
          children: [
            for (final kind in kinds)
              _KindRow(kind: kind, description: kind.description(l)),
            Text(
              l.miniAppPermissionRemembered,
              style: context.typography.caption.copyWith(color: c.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

class _KindRow extends StatelessWidget {
  const _KindRow({required this.kind, required this.description});

  final MiniAppPermissionKind kind;
  final String description;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: s.xl,
      children: [
        Container(
          padding: EdgeInsets.all(s.md),
          decoration: BoxDecoration(
            color: c.selectionFill,
            borderRadius: BorderRadius.circular(context.radii.lg),
          ),
          child: Icon(kind.icon, size: context.sizes.iconLg, color: c.accent),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: s.xs),
            child: Text(
              description,
              style: context.typography.body.copyWith(color: c.textSecondary),
            ),
          ),
        ),
      ],
    );
  }
}
