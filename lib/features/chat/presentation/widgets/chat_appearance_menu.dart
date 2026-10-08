import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/settings/app_settings.dart';
import '../../../../core/settings/chat_appearance.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';

/// Header menu to switch the chat layout style.
class ChatAppearanceMenu extends ConsumerWidget {
  const ChatAppearanceMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final current = ref.watch(
      appSettingsProvider.select((s) => s.chatAppearance),
    );
    return PopupMenuButton<ChatAppearance>(
      tooltip: l.chatAppearance,
      icon: Icon(Icons.style_outlined, color: context.colors.textSecondary),
      initialValue: current,
      onSelected: (a) =>
          ref.read(appSettingsProvider.notifier).setChatAppearance(a),
      itemBuilder: (_) => [
        for (final a in ChatAppearance.values)
          CheckedPopupMenuItem(
            value: a,
            checked: a == current,
            child: Text(_label(l, a)),
          ),
      ],
    );
  }

  /// Messenger names are brands and stay as they are in every language.
  static String _label(AppL10n l, ChatAppearance a) => switch (a) {
    ChatAppearance.worknexus => l.chatAppearanceDefault,
    ChatAppearance.telegram => 'Telegram',
    ChatAppearance.zalo => 'Zalo',
    ChatAppearance.messenger => 'Messenger',
    ChatAppearance.wechat => 'WeChat',
  };
}
