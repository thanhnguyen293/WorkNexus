import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../board_providers.dart';
import 'zentao_type_row.dart';

class ZenTaoProductsBranch extends ConsumerWidget {
  const ZenTaoProductsBranch({
    super.key,
    required this.accounts,
    required this.tickets,
  });

  final List<Account> accounts;
  final List<Ticket> tickets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(zentaoProductsExpandedProvider);
    final selected = ref.watch(selectedZenTaoProductProvider);
    final count = tickets
        .where(
          (ticket) =>
              (ticket.externalType ?? '').toLowerCase() == 'bug' &&
              ticket.labels.any((label) => label.startsWith('zentao-product:')),
        )
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ZenTaoTypeRow(
          label: 'Products',
          count: count,
          active: selected != null,
          onTap: () =>
              ref.read(zentaoProductsExpandedProvider.notifier).toggle(),
        ),
        if (expanded)
          for (final account in accounts)
            _AccountProducts(account: account, tickets: tickets),
      ],
    );
  }
}

class _AccountProducts extends ConsumerWidget {
  const _AccountProducts({required this.account, required this.tickets});

  final Account account;
  final List<Ticket> tickets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(zentaoProductsProvider(account.id));
    return Padding(
      padding: EdgeInsets.only(left: context.spacing.md),
      child: products.when(
        data: (items) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final product in items)
              _ProductRow(product: product, tickets: tickets),
          ],
        ),
        error: (error, _) => const _MutedRow(label: 'Cannot load products'),
        loading: () => const _MutedRow(label: 'Loading products'),
      ),
    );
  }
}

class _ProductRow extends ConsumerWidget {
  const _ProductRow({required this.product, required this.tickets});

  final ProviderProduct product;
  final List<Ticket> tickets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedZenTaoProductProvider);
    final syncing = ref.watch(zentaoProductSyncingProvider);
    final key = '${product.accountId}:${product.id}';
    final active =
        selected?.accountId == product.accountId &&
        selected?.productId == product.id;
    final loading = syncing == key;
    final count = tickets
        .where(
          (ticket) =>
              ticket.accountId == product.accountId &&
              ticket.labels.contains('zentao-product:${product.id}'),
        )
        .length;

    return Opacity(
      opacity: loading ? 0.48 : 1,
      child: ZenTaoTypeRow(
        label: product.name,
        count: count,
        active: active,
        onTap: loading
            ? null
            : () async {
                ref.read(zentaoProductSyncingProvider.notifier).start(product);
                final res = await ref
                    .read(syncServiceProvider)
                    .syncProductBugs(product);
                ref.read(zentaoProductSyncingProvider.notifier).finish();
                if (res case Ok()) {
                  ref
                      .read(selectedZenTaoProductProvider.notifier)
                      .select(product);
                  ref.read(viewModeProvider.notifier).set(ViewMode.zentaoBugs);
                }
              },
      ),
    );
  }
}

class _MutedRow extends StatelessWidget {
  const _MutedRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: 27,
      padding: EdgeInsets.symmetric(horizontal: context.spacing.sm),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(context.radii.sm),
      ),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: c.textTertiary,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: context.spacing.sm),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: context.typography.mono.copyWith(
                fontWeight: FontWeight.w500,
                color: c.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
