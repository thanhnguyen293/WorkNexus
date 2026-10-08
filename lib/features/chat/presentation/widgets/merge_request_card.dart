import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/platform/open_external.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/merge_request_state_pill.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/usecases/parse_merge_request_link.dart';
import '../providers/merge_request_providers.dart';
import 'chat_labels.dart';
import 'chat_link_card_frame.dart';

/// A GitLab merge request / GitHub pull request linked in a message, as a
/// compact quote-like card with its live state: `Merged · group/repo !12 ·
/// 2h ago`, the title, then `author · +lines −lines · files`. The bar takes
/// the state's colour. It is fetched through the connected account for the
/// link's host; a tap opens it beside the chat (or in the browser when it
/// could not be loaded).
class MergeRequestCard extends ConsumerWidget {
  const MergeRequestCard({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final link = const ParseMergeRequestLink()(url);
    if (link == null) return const SizedBox.shrink();
    final fetch = ref.watch(chatMergeRequestFetchProvider(url));
    final ticket = ref.watch(chatMergeRequestProvider(url));
    final state = ticket == null
        ? null
        : mergeRequestState(context, ticket.providerStatus, link.provider);
    return ChatLinkCardFrame(
      bar: state?.$1,
      onTap: () => ticket == null
          ? openExternally(url)
          : ref.read(openTicketIdProvider.notifier).open(ticket.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ChatCardLine(
            spans: [
              if (state != null) chatCardStrong(context, state.$2, state.$1),
              _reference(link),
              if (ticket?.updatedAt case final updated?)
                chatAgo(context, updated),
            ],
          ),
          if (ticket != null) ...[
            ChatCardTitle(ticket.title),
            _Footer(ticket: ticket),
          ] else
            _Note(
              loading: fetch.isLoading,
              host: link.host,
              failure: switch (fetch.value) {
                Err(:final failure) => failure,
                _ => null,
              },
            ),
        ],
      ),
    );
  }
}

/// `group/repo !12` (GitLab) or `owner/repo #12` (GitHub).
String _reference(MergeRequestLink link) =>
    '${link.project} ${link.provider == ProviderType.gitlab ? '!' : '#'}'
    '${link.number}';

/// `author · +1,867 −106 · 57 files`, as far as known.
class _Footer extends StatelessWidget {
  const _Footer({required this.ticket});

  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final (author, added, removed, files) = switch (ticket.providerEntity) {
      GitLabItemEntity(
        :final author,
        :final additions,
        :final deletions,
        :final changedFiles,
      ) =>
        (author, additions, deletions, changedFiles),
      GitHubItemEntity(
        :final author,
        :final additions,
        :final deletions,
        :final changedFiles,
      ) =>
        (author, additions, deletions, changedFiles),
      _ => (null, null, null, null),
    };
    String count(int n) => MaterialLocalizations.of(context).formatDecimal(n);
    final parts = <Object>[
      ?author,
      if (added != null && removed != null)
        TextSpan(
          children: [
            chatCardStrong(context, '+${count(added)}', c.success),
            const TextSpan(text: ' '),
            chatCardStrong(context, '−${count(removed)}', c.error),
          ],
        ),
      if (files != null) l.chatMrFiles(files),
    ];
    return parts.isEmpty ? const SizedBox.shrink() : ChatCardLine(spans: parts);
  }
}

/// Why there is no state yet: loading, no account for the host, or failed.
class _Note extends StatelessWidget {
  const _Note({
    required this.loading,
    required this.host,
    required this.failure,
  });

  final bool loading;
  final String host;
  final Failure? failure;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final failure = this.failure;
    return ChatCardLine(
      spans: [
        if (loading)
          l.chatMrLoading
        else if (failure is NotFoundFailure)
          l.chatMrNoAccount(host)
        else
          l.chatMrUnavailable,
      ],
    );
  }
}
