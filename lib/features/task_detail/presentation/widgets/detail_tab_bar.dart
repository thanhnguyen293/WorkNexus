import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../detail_providers.dart';

/// The detail panel's horizontal tab strip.
class DetailTabBar extends ConsumerWidget {
  const DetailTabBar({super.key, required this.current});
  final DetailTab current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final labels = {
      DetailTab.original: l.original,
      DetailTab.translation: '🇻🇳 ${l.vietnamese}',
      DetailTab.comments: '${l.comments} & ${l.activity}',
      DetailTab.development: l.development,
    };
    return Container(
      decoration: BoxDecoration(border: Border(bottom: context.hairlineSide)),
      padding: EdgeInsets.symmetric(horizontal: context.spacing.xl),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final e in labels.entries)
              GestureDetector(
                onTap: () => ref.read(detailTabProvider.notifier).set(e.key),
                child: Container(
                  height: 38,
                  alignment: Alignment.center,
                  padding: EdgeInsets.symmetric(horizontal: context.spacing.xl),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: e.key == current ? c.accent : Colors.transparent,
                        width: context.borders.thick,
                      ),
                    ),
                  ),
                  child: Text(
                    e.value,
                    style: context.typography.secondary.copyWith(
                      fontWeight: e.key == current
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: e.key == current ? c.textPrimary : c.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
