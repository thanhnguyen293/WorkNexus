import 'package:flutter/widgets.dart';

/// Chat list width, full and collapsed to avatars.
const double kChatListWidth = 320;
const double kChatListCompactWidth = 76;

/// Narrowest the message column may get before the info panel gives way,
/// then the chat list collapses.
const double kChatMessagesMinWidth = 520;

/// Width taken by a panel beside the chat (reply threads are a bit wider).
const double kChatPanelRoom = 380;

/// How the chat view fits its width: whether the info panel stays open
/// beside a chat (it only gives way when there is no room), and whether the
/// chat list collapses to avatars (once the info panel is gone and there is
/// still no room). A panel the user opens without room slides over the
/// messages instead (see `ChatSidePanelHost`), so it takes no width here.
@immutable
class ChatLayout {
  const ChatLayout({required this.infoRoom, required this.compactList});

  /// Lays out [width].
  factory ChatLayout.of(double width) {
    final infoRoom =
        width - kChatListWidth - kChatPanelRoom >= kChatMessagesMinWidth;
    final panel = infoRoom ? kChatPanelRoom : 0;
    return ChatLayout(
      infoRoom: infoRoom,
      compactList: width - kChatListWidth - panel < kChatMessagesMinWidth,
    );
  }

  final bool infoRoom;
  final bool compactList;
}

/// Provides the [ChatLayout] to the chat view's panels and buttons.
class ChatLayoutScope extends InheritedWidget {
  const ChatLayoutScope({
    super.key,
    required this.layout,
    required super.child,
  });

  final ChatLayout layout;

  /// Outside a chat page (tests, dialogs): no room for the info panel.
  static ChatLayout of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ChatLayoutScope>()?.layout ??
      const ChatLayout(infoRoom: false, compactList: false);

  @override
  bool updateShouldNotify(ChatLayoutScope oldWidget) =>
      oldWidget.layout.infoRoom != layout.infoRoom ||
      oldWidget.layout.compactList != layout.compactList;
}
