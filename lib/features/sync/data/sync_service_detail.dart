part of 'sync_service.dart';

/// A ticket's detail refresh and on-demand ZenTao ticket loads
/// ([TicketDetailService.syncTicketDetail], [ZenTaoTicketService]).
mixin _TicketDetailSync on _SyncCore {
  @override
  Future<Result<String>> fetchZenTaoTicket({
    required String host,
    required String type,
    required String id,
  }) async {
    final rows = await (_db.select(
      _db.accounts,
    )..where((a) => a.providerType.equals(ProviderType.zentao.name))).get();
    final account = rows
        .map(accountFromRow)
        .where((a) => Uri.tryParse(a.baseUrl ?? '')?.host == host)
        .firstOrNull;
    final credRef = account?.credentialsRef;
    if (account == null || credRef == null) {
      return const Err(NotFoundFailure('No ZenTao account for this link'));
    }
    final secret = await _credentials.read(credRef);
    final adapter = secret == null ? null : _buildAdapter(account, secret);
    if (adapter == null) {
      return const Err(AuthFailure('ZenTao account is not signed in'));
    }
    // Only the type and id matter to the detail request; the rest is filled
    // from the reply.
    final stub = Ticket(
      id: '${account.id}:$id',
      accountId: account.id,
      projectId: '${account.id}:$type',
      providerType: ProviderType.zentao,
      externalKey: id,
      externalType: '${type[0].toUpperCase()}${type.substring(1)}',
      title: '',
      body: '',
      priority: Priority.medium,
      status: UnifiedStatus.todo,
      providerStatus: '',
      sourceHash: '',
    );
    final detail = await adapter.getTicket(stub);
    switch (detail) {
      case Ok(:final value):
        await _db
            .into(_db.tickets)
            .insertOnConflictUpdate(ticketToCompanion(value));
        return Ok(value.id);
      case Err(:final failure):
        return Err(failure);
    }
  }

  /// Fetches full detail + comments for a single [ticket] from its provider and
  /// writes them into drift (from where the detail panel reads reactively).
  ///
  /// A no-op for tickets whose account has no stored credentials (e.g. seeded
  /// demo data) — the panel just shows the already-cached content. Network
  /// failures are swallowed so opening a card never throws; cached data stays.
  @override
  Future<Result<void>> syncTicketDetail(Ticket ticket) async {
    final accountRow = await (_db.select(
      _db.accounts,
    )..where((a) => a.id.equals(ticket.accountId))).getSingleOrNull();
    if (accountRow == null) return const Ok(null);
    final account = accountFromRow(accountRow);
    final credRef = account.credentialsRef;
    if (credRef == null) return const Ok(null);
    final secret = await _credentials.read(credRef);
    if (secret == null) return const Ok(null);
    final adapter = _buildAdapter(account, secret);
    if (adapter == null) return const Ok(null);

    // Fetched together: some providers (ZenTao) serve all three from one detail
    // payload and share the request instead of making three round trips.
    final (detail, comments, activity) = await (
      adapter.getTicket(ticket),
      adapter.listComments(ticket),
      adapter.listActivity(ticket),
    ).wait;
    if (detail case Err(:final failure)) return Err(failure);
    final value = (detail as Ok<Ticket>).value;
    // Keep the local identity/scope stable; refresh only the content fields.
    // Carry forward synthetic board-membership labels (e.g.
    // `zentao-product:<id>`, added by the product-board sync): the detail
    // endpoint doesn't return them, so dropping them would silently remove
    // the ticket from its product board the moment its detail is opened.
    final merged = value.copyWith(
      id: ticket.id,
      accountId: ticket.accountId,
      projectId: ticket.projectId,
      labels: mergeDetailLabels(value.labels, ticket.labels),
      providerEntity: _preserveLabelColors(
        value.providerEntity,
        ticket.providerEntity,
      ),
    );
    await _db
        .into(_db.tickets)
        .insertOnConflictUpdate(ticketToCompanion(merged));

    await _db.transaction(() async {
      if (comments case Ok(:final value)) {
        // Replace provider comments (keep the user's internal notes) so stale
        // rows from a previous sync don't linger.
        await (_db.delete(_db.comments)..where(
              (c) => c.ticketId.equals(ticket.id) & c.origin.equals('provider'),
            ))
            .go();
        for (final c in value) {
          await _db
              .into(_db.comments)
              .insertOnConflictUpdate(commentToCompanion(c));
        }
      }
      if (activity case Ok(:final value)) {
        await (_db.delete(
          _db.activities,
        )..where((a) => a.ticketId.equals(ticket.id))).go();
        for (final e in value) {
          await _db
              .into(_db.activities)
              .insertOnConflictUpdate(activityToCompanion(e));
        }
      }
    });
    return const Ok(null);
  }
}
