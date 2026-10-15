import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/domain/value_objects/provider_type.dart';
import '../core/tools/tool_module.dart';
import '../features/chat/presentation/pages/chat_page.dart';
import '../features/chat/presentation/providers/chat_providers.dart';
import '../features/chat/presentation/widgets/conversation_list_pane.dart';
import '../tools/github/github_module.dart';
import '../tools/gitlab/gitlab_module.dart';
import '../tools/zentao/zentao_module.dart';

/// Default tool registry mapping ProviderType to its ToolModule implementation.
final Map<ProviderType, ToolModule> defaultToolRegistry = {
  ProviderType.zentao: ZentaoModule(
    chatSection: (context) => const ChatPage(showConversationList: false),
    chatPane: (context) => const _ChatNavPane(),
    chatUnread: chatUnreadTotalProvider,
  ),
  ProviderType.github: const GithubModule(),
  ProviderType.gitlab: const GitlabModule(),
};

class _ChatNavPane extends ConsumerWidget {
  const _ChatNavPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountId = ref.watch(selectedChatAccountIdProvider);
    if (accountId == null) return const SizedBox.shrink();
    return ConversationListPane(accountId: accountId);
  }
}
