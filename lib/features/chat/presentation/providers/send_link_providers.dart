import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/usecases/send_link_to_chats.dart';
import '../../domain/usecases/send_text_message.dart';
import 'chat_providers.dart';

/// Shares a link (a ticket from its detail panel) into chats.
final sendLinkToChatsProvider = Provider<SendLinkToChats>(
  (ref) => SendLinkToChats(SendTextMessage(ref.watch(chatRepositoryProvider))),
);
