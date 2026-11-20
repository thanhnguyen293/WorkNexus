import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens the "send to chat" picker for [link] (shown as [title]) on chat
/// account [accountId]: the user picks chats and may add a message.
typedef SendToChat =
    Future<void> Function(
      BuildContext context, {
      required String accountId,
      required String title,
      required String link,
    });

/// Wired in from the chat feature by the app, so a ticket screen can share
/// into chat without importing it. Null (tests, no chat) means no button.
final sendToChatProvider = Provider<SendToChat?>((ref) => null);
