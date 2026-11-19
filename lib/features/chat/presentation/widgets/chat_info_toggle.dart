import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/error/result.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/chat_providers.dart';
import 'chat_layout.dart';
import 'chat_panels.dart';
import 'chat_snack.dart';

/// The chat header's button that shows or hides the chat info panel; drawn
/// pressed while the panel is on screen.
class ChatInfoToggle extends ConsumerWidget {
  const ChatInfoToggle({super.key, required this.thread});

  final ChatThreadKey thread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final infoRoom = ChatLayoutScope.of(context).infoRoom;
    final shown = watchChatInfoShown(ref, thread, infoRoom: infoRoom);
    return AppIconButton(
      icon: LucideIcons.panelRight300,
      tooltip: shown ? l.chatHideInfo : l.chatShowInfo,
      selected: shown,
      onPressed: () async {
        final result = await toggleChatInfo(ref, thread, infoRoom: infoRoom);
        if (result case Err(:final failure) when context.mounted) {
          showChatFailure(context, failure);
        }
      },
    );
  }
}
