import 'package:dio/dio.dart';

import '../../domain/adapters/provider_adapter.dart';
import '../../domain/entities/activity_event.dart';
import '../../domain/entities/comment.dart';
import '../../domain/entities/ticket.dart';
import '../../domain/value_objects/provider_type.dart';
import '../../domain/value_objects/repo_change.dart';
import '../../error/failure.dart';
import '../../error/result.dart';
import 'github_client.dart';
import 'github_normalize.dart';

part 'github_adapter_tickets.dart';
part 'github_adapter_directory.dart';
part 'github_adapter_actions.dart';
part 'github_adapter_pull_requests.dart';

/// GitHub implementation of [ProviderAdapter], bound to one account.
///
/// The shared interface is ZenTao-shaped, so the product/execution/bug-resolution
/// methods with no GitHub analogue are no-oped. GitHub-specific richness
/// (repo-scoped issue/PR boards, PR merge, issue close/reopen) lives on this
/// concrete class as extra public methods, called through GitHub-specific
/// `SyncService` paths — not through the interface. A PR is an issue with extra
/// fields, so comment/assign/close/reopen all route through the issues endpoints;
/// only merge and the rich PR board use the `/pulls` endpoints.
class GitHubAdapter extends _GitHubAdapterBase
    with
        _GitHubTicketReads,
        _GitHubDirectory,
        _GitHubActions,
        _GitHubPullRequests {
  GitHubAdapter({required super.accountId, required super.client});
}

/// The account binding, the API client and the request helpers (repo ref,
/// item kind, error mapping) every part of [GitHubAdapter] shares.
abstract class _GitHubAdapterBase implements ProviderAdapter {
  _GitHubAdapterBase({required this.accountId, required this._client});

  final String accountId;
  final GitHubClient _client;

  @override
  ProviderType get providerType => ProviderType.github;

  // ---- helpers ----

  GitHubKind _kindOf(Ticket t) =>
      (t.externalType ?? '').toLowerCase() == 'pullrequest'
      ? GitHubKind.pullRequest
      : GitHubKind.issue;

  /// The `owner/name` repo ref parsed from the ticket's `projectId`
  /// (`<accountId>:<owner/name>`), used in `/repos/:ref/…`. GitHub takes the
  /// slash literally, so (unlike GitLab's numeric id) it is NOT URL-encoded.
  String _repoRef(Ticket ticket) {
    final prefix = '$accountId:';
    return ticket.projectId.startsWith(prefix)
        ? ticket.projectId.substring(prefix.length)
        : ticket.projectId;
  }

  Future<Result<T>> _guard<T>(Future<T> Function() run) async {
    try {
      return Ok(await run());
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) {
        return Err(AuthFailure('GitHub authentication failed', cause: e));
      }
      if (code == 404) {
        return Err(NotFoundFailure('GitHub resource not found', cause: e));
      }
      final cause = e.error ?? e.message ?? e.type.name;
      return Err(
        NetworkFailure(
          'GitHub request failed [${e.type.name}]: $cause',
          cause: e,
        ),
      );
    } catch (e) {
      return Err(
        ParseFailure('GitHub response could not be parsed: $e', cause: e),
      );
    }
  }
}
