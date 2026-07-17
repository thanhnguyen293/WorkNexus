import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../translation/presentation/translation_providers.dart';
import '../../domain/usecases/derive_dev_context.dart';

/// The sidebar footer showing up to three currently-running agents.
class ActivitySection extends ConsumerWidget {
  const ActivitySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final c = context.colors;
    final tickets =
        ref.watch(ticketsProvider).asData?.value ?? const <Ticket>[];

    // Derive up to 3 running agents (translation loading or coding).
    const derive = DeriveDevContext();
    final loadingTr = ref.watch(translationControllerProvider);
    final items = <({String name, String text})>[];
    for (final tk in tickets) {
      if (items.length >= 3) break;
      final isLoading = loadingTr[tk.id]?.loading ?? false;
      final dev = derive(tk, translationLoading: isLoading);
      final a = dev.agent;
      if (a != null && a.running) {
        items.add((
          name: a.name,
          text: '${a.labelKey} ${dev.branch ?? tk.externalKey}',
        ));
      }
    }

    return Container(
      decoration: BoxDecoration(border: Border(top: context.hairlineSide)),
      padding: EdgeInsets.fromLTRB(
        context.spacing.xl,
        context.spacing.lg,
        context.spacing.xl,
        context.spacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l.activity.toUpperCase(),
                style: context.typography.labelLoose.copyWith(
                  color: c.textSecondary,
                ),
              ),
              const Spacer(),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: c.success,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: context.spacing.sm),
              Text(
                '${l.allSynced} · 2m',
                style: context.typography.monoXs.copyWith(
                  color: c.textTertiary,
                ),
              ),
            ],
          ),
          SizedBox(height: context.spacing.md),
          if (items.isEmpty)
            Text(
              '—',
              style: context.typography.caption.copyWith(color: c.textTertiary),
            )
          else
            for (final it in items)
              Padding(
                padding: EdgeInsets.only(bottom: context.spacing.sm),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: c.warning,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: context.spacing.sm),
                    Text(
                      it.name,
                      style: context.typography.mono.copyWith(
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      ),
                    ),
                    SizedBox(width: context.spacing.sm),
                    Expanded(
                      child: Text(
                        it.text,
                        overflow: TextOverflow.ellipsis,
                        style: context.typography.monoSm.copyWith(
                          color: c.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
