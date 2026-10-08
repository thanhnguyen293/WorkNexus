import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/domain/adapters/merge_request_link_service.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/usecases/find_linked_merge_request.dart';
import '../../domain/usecases/parse_merge_request_link.dart';

final mergeRequestLinkServiceProvider = Provider<MergeRequestLinkService>(
  (ref) => getIt<MergeRequestLinkService>(),
);

/// How long a fetched MR/PR state is trusted before a card seen again
/// fetches it anew.
const _kFresh = Duration(minutes: 5);

/// Fetches the MR/PR a link points to from its provider (and stores it);
/// the ticket id, or why it could not be loaded.
final chatMergeRequestFetchProvider = FutureProvider.autoDispose
    .family<Result<String>, String>((ref, url) async {
      final keep = ref.keepAlive();
      final timer = Timer(_kFresh, keep.close);
      ref.onDispose(timer.cancel);
      final link = const ParseMergeRequestLink()(url);
      if (link == null) {
        return const Err(UnexpectedFailure('Not a merge request link'));
      }
      return ref
          .watch(mergeRequestLinkServiceProvider)
          .fetchMergeRequest(
            provider: link.provider,
            host: link.host,
            project: link.project,
            number: link.number,
          );
    });

/// The stored MR/PR [url] points to (watched: updates when it is fetched or
/// synced again).
final chatMergeRequestProvider = Provider.autoDispose.family<Ticket?, String>(
  (ref, url) => const FindLinkedMergeRequest()(
    url,
    ref.watch(ticketsProvider).value ?? const [],
  ),
);
