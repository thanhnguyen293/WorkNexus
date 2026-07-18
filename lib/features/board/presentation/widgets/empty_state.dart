import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../board_providers.dart';

/// Shown when the active filters match no tickets — offers a "clear all".
class EmptyState extends ConsumerWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = AppL10n.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(context.radii.lg),
              border: Border.all(
                color: c.borderStrong,
                width: context.borders.medium,
              ),
            ),
            child: Text(
              '⌕',
              style: context.typography.display.copyWith(
                fontWeight: FontWeight.w400,
                color: c.textTertiary,
              ),
            ),
          ),
          SizedBox(height: context.spacing.xl),
          Text(
            l.emptyTitle,
            style: context.typography.titleSm.copyWith(color: c.textPrimary),
          ),
          SizedBox(height: context.spacing.xs),
          Text(
            l.emptyDesc,
            style: context.typography.secondary.copyWith(
              color: c.textSecondary,
            ),
          ),
          SizedBox(height: context.spacing.xl3),
          AppButton.filled(
            onPressed: () => ref.read(filterStateProvider.notifier).clearAll(),
            child: Text(l.clearAllFilters),
          ),
        ],
      ),
    );
  }
}
