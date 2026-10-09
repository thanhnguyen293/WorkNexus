import 'package:dio/dio.dart';

import '../../domain/adapters/gitlab_mr_adapter.dart';
import '../../domain/adapters/provider_adapter.dart';
import '../../domain/entities/activity_event.dart';
import '../../domain/entities/comment.dart';
import '../../domain/entities/ticket.dart';
import '../../domain/value_objects/provider_type.dart';
import '../../domain/value_objects/repo_change.dart';
import '../../error/failure.dart';
import '../../error/result.dart';
import 'gitlab_client.dart';
import 'gitlab_models.dart';
import 'gitlab_normalize.dart';

part 'gitlab_adapter_tickets.dart';
part 'gitlab_adapter_directory.dart';
part 'gitlab_adapter_actions.dart';
part 'gitlab_adapter_merge_requests.dart';

/// GitLab implementation of [ProviderAdapter], bound to one account.
///
/// The shared interface is ZenTao-shaped, so the product/execution/bug-resolution
/// methods that have no GitLab analogue are no-oped (empty results / unsupported).
/// GitLab-specific richness (project-scoped issue/MR boards, MR merge, issue
/// close/reopen) lives on this concrete class as extra public methods, called
/// through GitLab-specific `SyncService` paths — not through the interface.
class GitLabAdapter extends _GitLabAdapterBase
    with
        _GitLabTicketReads,
        _GitLabDirectory,
        _GitLabActions,
        _GitLabMergeRequests {
  GitLabAdapter({required super.accountId, required super.client});
}

/// The account binding, the API client and the request helpers (project ref,
/// item kind, notes, error mapping) every part of [GitLabAdapter] shares.
abstract class _GitLabAdapterBase implements GitLabMrAdapter {
  _GitLabAdapterBase({required this.accountId, required this._client});

  final String accountId;
  final GitLabClient _client;

  @override
  ProviderType get providerType => ProviderType.gitlab;

  // ---- helpers ----

  /// Issue/MR notes (comments + system activity) for a ticket.
  Future<List<GitLabNote>> _notes(Ticket ticket) {
    final ref = _projectRef(ticket);
    return _kindOf(ticket) == GitLabKind.issue
        ? _client.issueNotes(ref, ticket.externalKey)
        : _client.mrNotes(ref, ticket.externalKey);
  }

  Future<GitLabMergeRequest> _withCommitsBehind(
    String projectRef,
    GitLabMergeRequest mr,
  ) async {
    final source = mr.sourceBranch;
    final target = mr.targetBranch;
    if (source == null || source.isEmpty || target == null || target.isEmpty) {
      return mr;
    }
    final count = await _client.commitsBehindTarget(
      projectRef,
      sourceBranch: source,
      targetBranch: target,
    );
    return mr.copyWith(commitsBehind: count);
  }

  GitLabKind _kindOf(Ticket t) =>
      (t.externalType ?? '').toLowerCase() == 'mergerequest'
      ? GitLabKind.mergeRequest
      : GitLabKind.issue;

  /// The URL-encoded project ref (`group%2Fweb` or a numeric id) parsed from the
  /// ticket's `projectId` (`<accountId>:<path>`), used in `/projects/:ref/…`.
  String _projectRef(Ticket ticket) {
    final prefix = '$accountId:';
    final path = ticket.projectId.startsWith(prefix)
        ? ticket.projectId.substring(prefix.length)
        : ticket.projectId;
    return Uri.encodeComponent(path);
  }

  Future<Result<T>> _guard<T>(Future<T> Function() run) async {
    try {
      return Ok(await run());
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) {
        return Err(AuthFailure('GitLab authentication failed', cause: e));
      }
      if (code == 404) {
        return Err(NotFoundFailure('GitLab resource not found', cause: e));
      }
      final cause = e.error ?? e.message ?? e.type.name;
      return Err(
        NetworkFailure(
          'GitLab request failed [${e.type.name}]: $cause',
          cause: e,
        ),
      );
    } catch (e) {
      return Err(
        ParseFailure('GitLab response could not be parsed: $e', cause: e),
      );
    }
  }
}
