import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/chat_ai_providers.dart';
import '../providers/chat_auto_reply_providers.dart';
import '../providers/chat_providers.dart';
import 'chat_composer_controller.dart';

/// Keeps automatic reply ideas running for a composer while it is on
/// screen, and tells them when the user starts or stops typing. Draws
/// nothing: the ideas show in the composer's reply tray.
class ChatAutoReplyTrigger extends ConsumerStatefulWidget {
  const ChatAutoReplyTrigger({
    super.key,
    required this.draftKey,
    required this.text,
  });

  final ChatComposerKey draftKey;
  final ChatComposerController text;

  @override
  ConsumerState<ChatAutoReplyTrigger> createState() =>
      _ChatAutoReplyTriggerState();
}

class _ChatAutoReplyTriggerState extends ConsumerState<ChatAutoReplyTrigger> {
  @override
  void initState() {
    super.initState();
    widget.text.addListener(_typed);
    WidgetsBinding.instance.addPostFrameCallback((_) => _typed());
  }

  @override
  void didUpdateWidget(ChatAutoReplyTrigger old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      old.text.removeListener(_typed);
      widget.text.addListener(_typed);
    }
  }

  @override
  void dispose() {
    widget.text.removeListener(_typed);
    super.dispose();
  }

  void _typed() {
    if (!mounted) return;
    ref
        .read(chatAutoReplyProvider(widget.draftKey).notifier)
        .draftChanged(empty: widget.text.isBlank);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(chatAutoReplyProvider(widget.draftKey));
    // Watched so the names are loaded by the time a run starts.
    ref.watch(chatAiPeopleProvider(widget.draftKey.chat.accountId));
    return const SizedBox.shrink();
  }
}
