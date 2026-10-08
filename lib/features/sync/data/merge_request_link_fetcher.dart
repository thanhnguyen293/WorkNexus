import '../../../core/database/database.dart';
import '../../../core/domain/adapters/merge_request_link_service.dart';
import '../../../core/domain/adapters/provider_adapter.dart';
import '../../../core/domain/entities/account.dart';
import '../../../core/domain/entities/provider_entity.dart';
import '../../../core/domain/entities/ticket.dart';
import '../../../core/domain/value_objects/priority.dart';
import '../../../core/domain/value_objects/provider_type.dart';
import '../../../core/domain/value_objects/repo_change.dart';
import '../../../core/domain/value_objects/unified_status.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/platform/credential_store.dart';
import '../../../data/local/mappers.dart';
import '../../connections/data/github/github_adapter.dart';
import '../../connections/data/gitlab/gitlab_adapter.dart';
import '../../connections/data/provider_adapter_factory.dart';

/// [MergeRequestLinkService] over the connected GitLab/GitHub accounts: the
/// account whose host matches the link fetches the MR/PR, which is stored
/// with the other tickets (the chat then reads it from the database).
class MergeRequestLinkFetcher implements MergeRequestLinkService {
  MergeRequestLinkFetcher(this._db, this._credentials);

  final AppDatabase _db;
  final CredentialStore _credentials;

  @override
  Future<Result<String>> fetchMergeRequest({
    required ProviderType provider,
    required String host,
    required String project,
    required String number,
  }) async {
    if (provider != ProviderType.gitlab && provider != ProviderType.github) {
      return const Err(UnexpectedFailure('Only GitLab and GitHub links'));
    }
    final rows = await (_db.select(
      _db.accounts,
    )..where((a) => a.providerType.equals(provider.name))).get();
    final account = rows
        .map(accountFromRow)
        .where((a) => _hostOf(a) == host.toLowerCase())
        .firstOrNull;
    final credRef = account?.credentialsRef;
    if (account == null || credRef == null) {
      return Err(NotFoundFailure('No ${provider.name} account for $host'));
    }
    final secret = await _credentials.read(credRef);
    final adapter = secret == null
        ? null
        : buildProviderAdapter(account, secret);
    if (adapter == null) {
      return Err(AuthFailure('${provider.name} account is not signed in'));
    }
    // The adapters read the MR/PR from project + number; the rest is filled
    // from the reply.
    final stub = Ticket(
      id: '${account.id}:$project:$number',
      accountId: account.id,
      projectId: '${account.id}:$project',
      providerType: provider,
      externalKey: number,
      externalType: provider == ProviderType.gitlab
          ? 'MergeRequest'
          : 'PullRequest',
      title: '',
      body: '',
      priority: Priority.medium,
      status: UnifiedStatus.todo,
      providerStatus: '',
      sourceHash: '',
    );
    switch (await adapter.getTicket(stub)) {
      case Ok(:final value):
        final ticket = await _withChangeSize(adapter, value);
        await _db
            .into(_db.tickets)
            .insertOnConflictUpdate(ticketToCompanion(ticket));
        return Ok(ticket.id);
      case Err(:final failure):
        return Err(failure);
    }
  }

  /// Adds lines added/removed and files changed, for the chat card: GitHub
  /// sends them with the PR; GitLab only with its diffs. Without them (the
  /// diffs failed) the ticket is kept as it is.
  Future<Ticket> _withChangeSize(ProviderAdapter adapter, Ticket ticket) async {
    final entity = ticket.providerEntity;
    if (entity is GitHubItemEntity && entity.additions != null) return ticket;
    final changes = switch (adapter) {
      final GitLabAdapter a => await a.listMergeRequestChanges(ticket),
      final GitHubAdapter a => await a.listPullFiles(ticket),
      _ => null,
    };
    if (changes is! Ok<List<RepoFileChange>>) return ticket;
    final files = changes.value;
    final additions = files.fold(0, (sum, f) => sum + f.additions);
    final deletions = files.fold(0, (sum, f) => sum + f.deletions);
    return ticket.copyWith(
      providerEntity: switch (entity) {
        final GitLabItemEntity e => e.copyWith(
          additions: additions,
          deletions: deletions,
          changedFiles: files.length,
        ),
        final GitHubItemEntity e => e.copyWith(
          additions: additions,
          deletions: deletions,
          changedFiles: files.length,
        ),
        _ => entity,
      },
    );
  }

  /// The host an account's links use; GitHub accounts without a base URL
  /// are github.com.
  static String _hostOf(Account account) {
    final base = (account.baseUrl ?? '').trim();
    if (base.isEmpty) {
      return account.providerType == ProviderType.github ? 'github.com' : '';
    }
    final uri = Uri.tryParse(base.contains('://') ? base : 'https://$base');
    final host = uri?.host.toLowerCase() ?? '';
    // GitHub's API host stands for github.com.
    return host == 'api.github.com' ? 'github.com' : host;
  }
}
