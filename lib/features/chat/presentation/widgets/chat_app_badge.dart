import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/chat_providers.dart';

/// Keeps the unread count of followed chats on the app's icon (Dock,
/// taskbar, launcher). Wraps the app shell so it runs whichever view is open.
class ChatAppBadge extends ConsumerStatefulWidget {
  const ChatAppBadge({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ChatAppBadge> createState() => _ChatAppBadgeState();
}

class _ChatAppBadgeState extends ConsumerState<ChatAppBadge> {
  @override
  void initState() {
    super.initState();
    // Logs every ZenTao account into chat from launch, so the count is live
    // before the chat view is opened.
    ref.listenManual(chatAutoConnectProvider, (_, _) {});
    ref.listenManual(chatBadgeUnreadProvider, (_, count) => _show(count));
    // The count already there (chats loaded before this appeared) too, or
    // the icon only shows it once it next changes. After this frame: the
    // colours come from the theme.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _show(ref.read(chatBadgeUnreadProvider));
    });
  }

  void _show(int count) {
    final c = context.colors;
    unawaited(
      ref
          .read(appIconBadgeProvider)
          .show(count, color: c.error, textColor: c.onAccent),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
