import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/chat_providers.dart';

/// Switches between ZenTao accounts; hidden when there is only one.
class ChatAccountPicker extends ConsumerWidget {
  const ChatAccountPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(chatAccountsProvider);
    if (accounts.length < 2) return const SizedBox.shrink();
    final c = context.colors;
    final selected = ref.watch(selectedChatAccountIdProvider);
    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.md),
      child: DropdownButton<String>(
        value: selected,
        isExpanded: true,
        isDense: true,
        underline: const SizedBox.shrink(),
        hint: Text(AppL10n.of(context).chatAccount),
        style: context.typography.secondary.copyWith(color: c.textPrimary),
        dropdownColor: c.surface,
        items: [
          for (final a in accounts)
            DropdownMenuItem(
              value: a.id,
              child: Text(
                a.baseUrl == null
                    ? a.handle
                    : '${a.handle} · ${Uri.tryParse(a.baseUrl!)?.host ?? a.baseUrl}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (id) =>
            ref.read(pickedChatAccountProvider.notifier).state = id,
      ),
    );
  }
}
