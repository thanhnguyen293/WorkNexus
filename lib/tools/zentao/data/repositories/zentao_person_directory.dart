import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../core/database/database.dart';
import '../../../../core/debug/app_talker.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/entities/person_profile.dart';
import '../../../../core/domain/repositories/person_directory.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/platform/credential_store.dart';
import '../datasources/zentao_client.dart';
import '../mappers/zentao_person_mapper.dart';
import 'local_zentao_profile_repository.dart';

/// [PersonDirectory] over ZenTao REST v1 `GET /users/{id}`. ZenTao user ids
/// are the chat (xxd) user ids, so chat can ask by its own id.
class ZenTaoPersonDirectory implements PersonDirectory {
  ZenTaoPersonDirectory(
    this._db,
    this._credentials, {
    required this._clientFactory,
  });

  final AppDatabase _db;
  final CredentialStore _credentials;
  final ZenTaoProfileClientFactory _clientFactory;

  /// Departments per account, fetched once: they rarely change and every
  /// profile popup needs them.
  final _departments = <String, List<Map<String, dynamic>>>{};

  @override
  Future<Result<PersonProfile>> lookup(Account account, int userId) async {
    try {
      final client = await _clientFor(account);
      if (client == null) {
        return const Err(AuthFailure('No ZenTao connection credentials'));
      }
      final json = await client.getV1Json('/users/$userId');
      return Ok(
        mapZenTaoPerson(
          json,
          departments: await _departmentsOf(account.id, client),
        ),
      );
    } on DioException catch (error) {
      final code = error.response?.statusCode;
      return Err(switch (code) {
        401 || 403 => AuthFailure('No access to ZenTao users', cause: error),
        404 => NotFoundFailure('ZenTao user $userId not found', cause: error),
        _ => NetworkFailure('Could not load ZenTao user', cause: error),
      });
    } on FormatException catch (error) {
      return Err(ParseFailure('Invalid ZenTao user', cause: error));
    } on Exception catch (error) {
      return Err(UnexpectedFailure('Could not load ZenTao user', cause: error));
    }
  }

  /// The departments the signed-in profile cached, else asked of the server;
  /// none (no department path) when both fail.
  Future<List<Map<String, dynamic>>> _departmentsOf(
    String accountId,
    ZenTaoClient client,
  ) async {
    if (_departments[accountId] case final cached?) return cached;
    final row = await (_db.select(
      _db.zenTaoProfiles,
    )..where((r) => r.accountId.equals(accountId))).getSingleOrNull();
    final stored = row == null ? null : jsonDecode(row.profileJson);
    final raw = stored is Map ? stored['departments'] : null;
    var departments = [
      if (raw is List)
        for (final item in raw)
          if (item is Map) Map<String, dynamic>.from(item),
    ];
    if (departments.isEmpty) {
      try {
        departments = await client.departments();
      } on Exception catch (error, stackTrace) {
        appTalker.handle(error, stackTrace, 'ZenTao department lookup failed');
        return const [];
      }
    }
    return _departments[accountId] = departments;
  }

  Future<ZenTaoClient?> _clientFor(Account account) async {
    final ref = account.credentialsRef;
    final baseUrl = account.baseUrl;
    if (ref == null || baseUrl == null || baseUrl.isEmpty) return null;
    final password = await _credentials.read(ref);
    if (password == null || password.isEmpty) return null;
    return _clientFactory(account, password);
  }
}
