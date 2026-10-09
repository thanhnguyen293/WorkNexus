import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../core/database/database.dart';
import '../../../../core/debug/app_talker.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/platform/credential_store.dart';
import '../../domain/entities/zentao_department.dart';
import '../../domain/entities/zentao_profile.dart';
import '../../domain/entities/zentao_profile_update.dart';
import '../../domain/repositories/zentao_profile_repository.dart';
import '../mappers/zentao_profile_mapper.dart';
import '../zentao/zentao_client.dart';

typedef ZenTaoProfileClientFactory =
    ZenTaoClient Function(String baseUrl, String account, String password);

class LocalZenTaoProfileRepository implements ZenTaoProfileRepository {
  LocalZenTaoProfileRepository(
    this._db,
    this._credentials, {
    ZenTaoProfileClientFactory? clientFactory,
  }) : _clientFactory = clientFactory ?? _createClient;

  final AppDatabase _db;
  final CredentialStore _credentials;
  final ZenTaoProfileClientFactory _clientFactory;

  static ZenTaoClient _createClient(
    String baseUrl,
    String account,
    String password,
  ) => ZenTaoClient(baseUrl: baseUrl, account: account, password: password);

  @override
  Stream<ZenTaoProfile?> watch(String accountId) =>
      (_db.select(_db.zenTaoProfiles)
            ..where((row) => row.accountId.equals(accountId)))
          .watchSingleOrNull()
          .map(
            (row) => row == null
                ? null
                : mapZenTaoProfile(
                    accountId,
                    jsonDecode(row.profileJson) as Map<String, dynamic>,
                  ),
          );

  @override
  Stream<List<ZenTaoDepartment>> watchDepartments(String accountId) =>
      (_db.select(_db.zenTaoProfiles)
            ..where((row) => row.accountId.equals(accountId)))
          .watchSingleOrNull()
          .map((row) {
            if (row == null) return <ZenTaoDepartment>[];
            final stored = jsonDecode(row.profileJson) as Map<String, dynamic>;
            final raw = stored['departments'];
            if (raw is! List) return <ZenTaoDepartment>[];
            return mapZenTaoDepartments([
              for (final item in raw)
                if (item is Map) Map<String, dynamic>.from(item),
            ]);
          });

  @override
  Future<Result<ZenTaoProfile>> refresh(Account account) async {
    final credentialRef = account.credentialsRef;
    final baseUrl = account.baseUrl;
    if (credentialRef == null || baseUrl == null || baseUrl.isEmpty) {
      return const Err(AuthFailure('No ZenTao connection credentials'));
    }
    try {
      final password = await _credentials.read(credentialRef);
      if (password == null || password.isEmpty) {
        return const Err(AuthFailure('ZenTao password is missing'));
      }
      final client = _clientFactory(baseUrl, account.handle, password);
      final json = await client.userInfo();
      final profileJson = json['profile'];
      if (profileJson is! Map) {
        return const Err(ParseFailure('ZenTao response has no profile'));
      }
      final profile = Map<String, dynamic>.from(profileJson);
      if (profile['avatar'] case final String avatar when avatar.isNotEmpty) {
        profile['avatar'] = Uri.parse('$baseUrl/').resolve(avatar).toString();
      }
      final deptId = int.tryParse('${profile['dept']}') ?? 0;
      List<Map<String, dynamic>> departments = [];
      try {
        departments = await client.departments();
        if (deptId > 0) {
          profile['departmentPath'] = zenTaoDepartmentPath(deptId, departments);
        }
      } catch (error, stackTrace) {
        appTalker.handle(error, stackTrace, 'ZenTao department lookup failed');
      }
      final stored = <String, dynamic>{
        'profile': profile,
        'departments': departments,
      };
      final mapped = mapZenTaoProfile(account.id, stored, baseUrl: baseUrl);
      await _db
          .into(_db.zenTaoProfiles)
          .insertOnConflictUpdate(
            ZenTaoProfilesCompanion.insert(
              accountId: account.id,
              profileJson: jsonEncode(stored),
            ),
          );
      return Ok(mapped);
    } on DioException catch (error) {
      final code = error.response?.statusCode;
      return Err(
        code == 401 || code == 403
            ? AuthFailure('ZenTao authentication failed', cause: error)
            : NetworkFailure('Could not load ZenTao profile', cause: error),
      );
    } on FormatException catch (error) {
      return Err(ParseFailure('Invalid ZenTao profile', cause: error));
    } on Exception catch (error) {
      return Err(
        UnexpectedFailure('Could not save ZenTao profile', cause: error),
      );
    }
  }

  @override
  Future<Result<ZenTaoProfile>> update(
    Account account,
    ZenTaoProfileUpdate changes,
  ) async {
    try {
      final row = await (_db.select(
        _db.zenTaoProfiles,
      )..where((item) => item.accountId.equals(account.id))).getSingleOrNull();
      if (row == null) {
        return const Err(NotFoundFailure('Profile is not cached'));
      }
      final stored = jsonDecode(row.profileJson) as Map<String, dynamic>;
      final profile = Map<String, dynamic>.from(stored['profile'] as Map);
      final userId = int.tryParse('${profile['id']}');
      if (userId == null) {
        return const Err(ParseFailure('ZenTao profile has no user ID'));
      }
      final client = await _clientFor(account);
      if (client == null) {
        return const Err(AuthFailure('No ZenTao connection credentials'));
      }
      final oldRole = profile['role'];
      final oldRoleCode = oldRole is Map ? oldRole['code'] : oldRole;
      final fields = <String, dynamic>{
        if (profile['realname'] != changes.realname)
          'realname': changes.realname,
        if ((profile['email'] ?? '') != changes.email) 'email': changes.email,
        if ((profile['mobile'] ?? '') != changes.mobile)
          'mobile': changes.mobile,
        if ((profile['phone'] ?? '') != changes.phone) 'phone': changes.phone,
        if (changes.departmentId != null &&
            int.tryParse('${profile['dept']}') != changes.departmentId)
          'dept': changes.departmentId,
        if (changes.roleCode != null && oldRoleCode != changes.roleCode)
          'role': changes.roleCode,
      };
      if (fields.isEmpty) return Ok(mapZenTaoProfile(account.id, stored));
      await client.updateUser(userId, fields);
      profile.addAll(fields);
      if (fields.containsKey('role')) {
        profile['role'] = {'code': changes.roleCode, 'name': changes.roleCode};
      }
      if (fields.containsKey('dept')) {
        final raw = stored['departments'];
        if (raw is List) {
          profile['departmentPath'] = zenTaoDepartmentPath(
            changes.departmentId!,
            [for (final item in raw) Map<String, dynamic>.from(item as Map)],
          );
        }
      }
      stored['profile'] = profile;
      await _db
          .into(_db.zenTaoProfiles)
          .insertOnConflictUpdate(
            ZenTaoProfilesCompanion.insert(
              accountId: account.id,
              profileJson: jsonEncode(stored),
            ),
          );
      final refreshed = await refresh(account);
      return refreshed is Ok<ZenTaoProfile>
          ? refreshed
          : Ok(mapZenTaoProfile(account.id, stored));
    } on DioException catch (error) {
      return Err(_httpFailure(error, 'Could not update ZenTao profile'));
    } on Exception catch (error) {
      return Err(
        UnexpectedFailure('Could not update ZenTao profile', cause: error),
      );
    }
  }

  Future<ZenTaoClient?> _clientFor(Account account) async {
    final ref = account.credentialsRef;
    final baseUrl = account.baseUrl;
    if (ref == null || baseUrl == null || baseUrl.isEmpty) {
      return null;
    }
    final password = await _credentials.read(ref);
    if (password == null || password.isEmpty) {
      return null;
    }
    return _clientFactory(baseUrl, account.handle, password);
  }

  Failure _httpFailure(DioException error, String message) {
    final code = error.response?.statusCode;
    return code == 401 || code == 403
        ? AuthFailure('ZenTao authentication failed', cause: error)
        : NetworkFailure(message, cause: error);
  }
}
