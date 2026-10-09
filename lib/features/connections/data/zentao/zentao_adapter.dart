import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/entities/activity_event.dart';
import '../../../../core/domain/entities/comment.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/api_paging.dart';
import '../../../../core/util/in_flight.dart';
import '../../../../core/util/synthetic_labels.dart';
import 'zentao_client.dart';
import 'zentao_models.dart';
import 'zentao_normalize.dart';

part 'zentao_adapter_tickets.dart';
part 'zentao_adapter_catalog.dart';
part 'zentao_adapter_actions.dart';

/// ZenTao implementation of [ProviderAdapter], bound to one account.
class ZenTaoAdapter extends _ZenTaoAdapterBase
    with _ZenTaoTicketReads, _ZenTaoCatalog, _ZenTaoActions {
  ZenTaoAdapter({required super.accountId, required super.client});
}

/// The account binding, the API client and the helpers (shared detail fetch,
/// ticket type mapping, error mapping) every part of [ZenTaoAdapter] shares.
abstract class _ZenTaoAdapterBase implements ProviderAdapter {
  _ZenTaoAdapterBase({required this.accountId, required this._client});

  final String accountId;
  final ZenTaoClient _client;

  @override
  ProviderType get providerType => ProviderType.zentao;

  // ---- helpers ----

  /// Detail fetches in flight, keyed by type + id. Opening a ticket asks for
  /// its detail, comments and activity at once — all read from this one
  /// payload — so concurrent callers share a single request; a later call
  /// still refetches.
  final _detailsInFlight = InFlight<String, ZenTaoEntity>();

  Future<ZenTaoEntity> _fetchDetail(Ticket ticket) => _detailsInFlight.run(
    '${_typeOf(ticket).pathSegment}-${ticket.externalKey}',
    () => _loadDetail(ticket),
  );

  /// Fetches a ticket's full detail (with its embedded `actions`), preferring
  /// REST v1 and falling back to the classic `{type}-view-{id}.json` endpoint
  /// when v1 returns an empty body.
  Future<ZenTaoEntity> _loadDetail(Ticket ticket) async {
    final type = _typeOf(ticket);
    final entity = await _client.api.entity(_plural(type), ticket.externalKey);
    if (entity.idString.isNotEmpty) return entity;
    final fallback = await _client.classicViewJson(
      type.pathSegment,
      ticket.externalKey,
    );
    return fallback == null ? entity : ZenTaoEntity.fromJson(fallback);
  }

  ZenTaoType _typeOf(Ticket t) => switch (t.externalType) {
    'Task' => ZenTaoType.task,
    'Story' => ZenTaoType.story,
    _ => ZenTaoType.bug,
  };

  String _plural(ZenTaoType t) => switch (t) {
    ZenTaoType.bug => 'bugs',
    ZenTaoType.task => 'tasks',
    ZenTaoType.story => 'stories',
  };

  Future<Result<T>> _guard<T>(Future<T> Function() run) async {
    try {
      return Ok(await run());
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) {
        return Err(AuthFailure('ZenTao authentication failed', cause: e));
      }
      // Surface the real cause (e.g. HandshakeException / SocketException / 404).
      final cause = e.error ?? e.message ?? e.type.name;
      return Err(
        NetworkFailure(
          'ZenTao request failed [${e.type.name}]: $cause',
          cause: e,
        ),
      );
    } catch (e) {
      return Err(
        ParseFailure('ZenTao response could not be parsed: $e', cause: e),
      );
    }
  }
}
