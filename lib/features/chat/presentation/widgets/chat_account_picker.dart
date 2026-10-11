import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_dropdown.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/chat_providers.dart';

/// Switches between ZenTao accounts; hidden when there is only one.
class ChatAccountPicker extends ConsumerWidget {
  const ChatAccountPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(chatAccountsProvider);
    if (accounts.length < 2) return const SizedBox.shrink();
    final selected = ref.watch(selectedChatAccountIdProvider);
    final l = AppL10n.of(context);
    final s = context.spacing;
    String labelOf(String? id) {
      final a = accounts.where((a) => a.id == id).firstOrNull;
      if (a == null) return l.chatAccount;
      final url = a.baseUrl;
      return url == null
          ? a.handle
          : '${a.handle} · ${Uri.tryParse(url)?.host ?? url}';
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(s.xl3, s.md, s.xl3, s.md),
      child: AppDropdown<String?>(
        value: selected,
        values: [for (final a in accounts) a.id],
        labelOf: labelOf,
        tooltip: l.chatAccount,
        onChanged: (id) =>
            ref.read(pickedChatAccountProvider.notifier).state = id,
      ),
    );
  }
}
