import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/chat_providers.dart';

/// Keeps the unread count of followed chats on the app's icon (Dock,
/// taskbar, launcher). Wraps the app shell so it runs whichever view is open.
class ChatAppBadge extends ConsumerWidget {
  const ChatAppBadge({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(chatBadgeUnreadProvider, (_, count) {
      final c = context.colors;
      unawaited(
        ref
            .read(appIconBadgeProvider)
            .show(count, color: c.error, textColor: c.onAccent),
      );
    });
    return child;
  }
}
