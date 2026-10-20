import 'package:dio/dio.dart';

import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/entities/zentao_ticket_form.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/sync/data/sync_coordinator.dart';
import '../../domain/repositories/zentao_team_members.dart';
import '../datasources/zentao_client.dart';
import '../models/zentao_ticket_forms.dart';

/// [ZenTaoTeamMembers] read from ZenTao's new bug and new task forms over each
/// account's pooled client.
class ClassicZenTaoTeamMembers implements ZenTaoTeamMembers {
  const ClassicZenTaoTeamMembers(this._coordinator);

  final SyncCoordinator _coordinator;

  /// The initial ZenTao puts before each name in its member lists (`T:Thanh`)
  /// to sort them; a bug names its opener and resolver without it.
  static final _initial = RegExp(r'^\p{L}:', unicode: true);

  @override
  Future<Result<List<ProviderUser>>> productMembers(
    String accountId,
    String productId,
  ) => _run(accountId, (forms) => forms.productMembers(productId));

  @override
  Future<Result<List<ProviderUser>>> executionMembers(
    String accountId,
    String executionId,
  ) => _run(accountId, (forms) => forms.executionMembers(executionId));

  Future<Result<List<ProviderUser>>> _run(
    String accountId,
    Future<List<FormOption>> Function(ZenTaoTicketForms forms) read,
  ) async {
    final client = await _coordinator.rawClientFor(accountId);
    if (client is! ZenTaoClient) {
      return const Err(AuthFailure('ZenTao account is not signed in'));
    }
    try {
      final options = await read(ZenTaoTicketForms(client));
      return Ok([
        for (final o in options)
          ProviderUser(
            account: o.value,
            displayName: o.label.replaceFirst(_initial, ''),
          ),
      ]);
    } on Failure catch (failure) {
      return Err(failure);
    } on DioException catch (e) {
      return Err(
        NetworkFailure(e.message ?? 'ZenTao request failed', cause: e),
      );
    } on FormatException catch (e) {
      return Err(ParseFailure('ZenTao sent an unreadable form', cause: e));
    }
  }
}
