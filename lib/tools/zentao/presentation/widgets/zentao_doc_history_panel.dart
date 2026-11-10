import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/app_popup_card.dart';
import '../../../../core/widgets/app_state_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/zentao_doc_action.dart';
import '../providers/zentao_doc_providers.dart';

import 'zentao_doc_history_entry.dart';

/// A document's history, as ZenTao's web lists it: numbered entries down a
/// line — when, who, what — each with what changed one tap away.
class ZenTaoDocHistoryPanel extends ConsumerWidget {
  const ZenTaoDocHistoryPanel({
    super.key,
    required this.account,
    required this.docId,
    required this.onClose,
  });

  final Account account;
  final String docId;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final c = context.colors;
    final s = context.spacing;
    final syncKey = (account: account, docId: docId);
    final sync = ref.watch(zentaoDocHistorySyncProvider(syncKey));
    final entries =
        ref
            .watch(
              zentaoDocHistoryProvider((accountId: account.id, docId: docId)),
            )
            .asData
            ?.value ??
        const <ZenTaoDocAction>[];

    final Widget body;
    if (entries.isNotEmpty) {
      // A plain column, not a lazy list: a popover measures what it holds,
      // which a lazy list can't answer — and a history is short.
      body = SingleChildScrollView(
        primary: false,
        padding: EdgeInsets.fromLTRB(s.xl, s.xs, s.md, s.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < entries.length; i++)
              ZenTaoDocHistoryEntry(
                number: i + 1,
                entry: entries[i],
                last: i == entries.length - 1,
              ),
          ],
        ),
      );
    } else if (sync.isLoading) {
      body = const AppStateView.loading(compact: true);
    } else if (sync.hasError) {
      body = AppStateView.error(
        compact: true,
        title: l.docsHistoryUnavailable,
        onRetry: () => ref.invalidate(zentaoDocHistorySyncProvider(syncKey)),
      );
    } else {
      body = AppStateView.empty(
        title: l.docsHistoryEmpty,
        icon: LucideIcons.history300,
        compact: true,
      );
    }

    return AppPopupCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(s.xl, s.md, s.sm, s.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l.docsHistory,
                    style: context.typography.title.copyWith(
                      color: c.textPrimary,
                    ),
                  ),
                ),
                AppIconButton(
                  icon: LucideIcons.rotateCw300,
                  tooltip: l.retry,
                  isLoading: sync.isLoading,
                  onPressed: () =>
                      ref.invalidate(zentaoDocHistorySyncProvider(syncKey)),
                ),
                AppIconButton(
                  icon: LucideIcons.x300,
                  tooltip: l.close,
                  onPressed: onClose,
                ),
              ],
            ),
          ),
          Flexible(child: body),
        ],
      ),
    );
  }
}
