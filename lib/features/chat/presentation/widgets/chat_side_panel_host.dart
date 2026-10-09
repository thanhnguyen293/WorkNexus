import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'chat_layout.dart';

/// How much the messages are dimmed under a panel drawn over them.
const double _kScrimAlpha = 0.18;

/// The open chat with a panel (thread, info, pinned messages, files): beside
/// the messages when they keep their minimum width, else slid over them from
/// the right — squeezing them would wrap text a few letters per line. Over
/// the messages, a click outside the panel calls [onDismiss].
class ChatSidePanelHost extends StatelessWidget {
  const ChatSidePanelHost({
    super.key,
    required this.messages,
    required this.panel,
    required this.onDismiss,
  });

  final Widget messages;

  /// Null when no panel is open.
  final Widget? panel;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final panel = this.panel;
    if (panel == null) return messages;
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth - kChatPanelRoom >= kChatMessagesMinWidth) {
          return Row(
            children: [
              Expanded(child: messages),
              panel,
            ],
          );
        }
        final c = context.colors;
        return Stack(
          children: [
            messages,
            Positioned.fill(
              child: ModalBarrier(
                color: c.scrim.withValues(alpha: _kScrimAlpha),
                onDismiss: onDismiss,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: c.scrim.withValues(alpha: _kScrimAlpha),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: panel,
              ),
            ),
          ],
        );
      },
    );
  }
}
