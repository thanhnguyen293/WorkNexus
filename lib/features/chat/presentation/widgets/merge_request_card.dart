import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/platform/open_external.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/badges.dart';
import '../../../../core/widgets/merge_request_state_pill.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/usecases/parse_merge_request_link.dart';
import '../providers/merge_request_providers.dart';
import 'chat_bubble_theme.dart';
import 'chat_labels.dart';
import 'merge_request_card_parts.dart';

/// Fixed card size, so the list does not jump when the state arrives.
const double _kCardHeight = 112;
const double _kCardMaxWidth = 460;

/// A GitLab merge request / GitHub pull request linked in a message, with
/// its live state: the state chip, `group/repo #12` and when it last
/// changed; its title; the author and the size of the change (+lines,
/// −lines, files). It is fetched through the connected account for the
/// link's host; a tap opens it beside the chat (or in the browser when it
/// could not be loaded).
class MergeRequestCard extends ConsumerWidget {
  const MergeRequestCard({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final link = const ParseMergeRequestLink()(url);
    if (link == null) return const SizedBox.shrink();
    final ink = ChatBubbleTheme.of(context);
    final s = context.spacing;
    final fetch = ref.watch(chatMergeRequestFetchProvider(url));
    final ticket = ref.watch(chatMergeRequestProvider(url));
    final radius = BorderRadius.circular(context.radii.lg);
    return Padding(
      padding: EdgeInsets.only(top: s.md),
      child: InkWell(
        borderRadius: radius,
        onTap: () => ticket == null
            ? openExternally(url)
            : ref.read(openTicketIdProvider.notifier).open(ticket.id),
        child: Container(
          height: _kCardHeight,
          constraints: const BoxConstraints(maxWidth: _kCardMaxWidth),
          padding: EdgeInsets.symmetric(horizontal: s.xl, vertical: s.lg),
          decoration: BoxDecoration(
            color: ink.quoteFill,
            borderRadius: radius,
            border: Border.all(color: ink.meta.withValues(alpha: 0.2)),
          ),
          child: ticket == null
              ? _Pending(
                  link: link,
                  loading: fetch.isLoading,
                  failure: switch (fetch.value) {
                    Err(:final failure) => failure,
                    _ => null,
                  },
                )
              : _Details(link: link, ticket: ticket),
        ),
      ),
    );
  }
}

/// `group/repo !12` (GitLab) or `owner/repo #12` (GitHub).
String _reference(MergeRequestLink link) =>
    '${link.project} ${link.provider == ProviderType.gitlab ? '!' : '#'}'
    '${link.number}';

class _Details extends StatelessWidget {
  const _Details({required this.link, required this.ticket});

  final MergeRequestLink link;
  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    final ink = ChatBubbleTheme.of(context);
    final s = context.spacing;
    final meta = context.typography.secondary.copyWith(color: ink.meta);
    final updated = ticket.updatedAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            MergeRequestStatePill(
              status: ticket.providerStatus,
              provider: link.provider,
            ),
            SizedBox(width: s.md),
            Expanded(
              child: Text(
                _reference(link),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: meta,
              ),
            ),
            if (updated != null) Text(chatAgo(context, updated), style: meta),
          ],
        ),
        SizedBox(height: s.sm),
        Expanded(
          child: Text(
            ticket.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.typography.bodyStrong.copyWith(color: ink.text),
          ),
        ),
        MergeRequestFooter(ticket: ticket),
      ],
    );
  }
}

/// Before the MR/PR is known: the reference from the link and why there is
/// no state yet.
class _Pending extends StatelessWidget {
  const _Pending({
    required this.link,
    required this.loading,
    required this.failure,
  });

  final MergeRequestLink link;
  final bool loading;
  final Failure? failure;

  @override
  Widget build(BuildContext context) {
    final ink = ChatBubbleTheme.of(context);
    final l = AppL10n.of(context);
    final s = context.spacing;
    final failure = this.failure;
    final note = loading
        ? l.chatMrLoading
        : failure is NotFoundFailure
        ? l.chatMrNoAccount(link.host)
        : l.chatMrUnavailable;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            ProviderBadge(link.provider, big: true),
            SizedBox(width: s.md),
            Expanded(
              child: Text(
                _reference(link),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.typography.bodyStrong.copyWith(color: ink.text),
              ),
            ),
          ],
        ),
        SizedBox(height: s.sm),
        Text(note, style: context.typography.bodySm.copyWith(color: ink.meta)),
      ],
    );
  }
}
