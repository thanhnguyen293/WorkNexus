import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/error/result.dart';
import '../../../../core/widgets/app_context_menu.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/chat_presence.dart';
import '../providers/chat_providers.dart';
import 'chat_avatar.dart';
import 'chat_labels.dart';
import 'chat_snack.dart';

/// The menu under your own avatar: open your profile, or switch your
/// presence (busy / in meeting / away / online), the current one checked.
Future<void> showChatSelfMenu(
  BuildContext context,
  WidgetRef ref, {
  required String accountId,
  required ChatPresence? current,
  required Offset at,
  required VoidCallback onOpenProfile,
}) async {
  final l = AppL10n.of(context);
  const presences = ChatPresence.selectable;
  final picked = await showAppContextMenu(
    context,
    at: at,
    entries: [
      AppMenuEntry(icon: LucideIcons.userRound, label: l.chatMyProfile),
      for (final (i, p) in presences.indexed)
        AppMenuEntry(
          icon: _icon(p),
          iconColor: chatPresenceColor(context, p),
          label: chatPresenceLabel(context, p),
          checked: p == current,
          dividerBefore: i == 0,
        ),
    ],
  );
  if (picked == null || !context.mounted) return;
  if (picked == 0) return onOpenProfile();
  final presence = presences[picked - 1];
  if (presence == current) return;
  final result = await ref
      .read(chatControllerProvider)
      .setMyPresence(accountId, presence);
  if (result case Err(:final failure)) {
    if (context.mounted) showChatFailure(context, failure);
  }
}

IconData _icon(ChatPresence p) => switch (p) {
  ChatPresence.busy => LucideIcons.monitor,
  ChatPresence.meeting => LucideIcons.calendarDays,
  ChatPresence.away => LucideIcons.clock,
  ChatPresence.online || ChatPresence.offline => LucideIcons.circleCheck,
};
