import 'dart:io';

import '../../../../core/domain/entities/opencode_credential.dart';
import '../../../../core/domain/repositories/opencode_auth_repository.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../datasources/opencode_auth_file.dart';

/// [OpenCodeAuthRepository] backed by OpenCode's own `auth.json`.
///
/// Saving here is the programmatic equivalent of `opencode auth login`, so a
/// changed key applies to everything that shells out to `opencode` — ticket
/// translation and dispatched coding-agent runs alike — and keeps usage on the
/// user's own OpenCode account.
class OpenCodeAuthFileRepository implements OpenCodeAuthRepository {
  const OpenCodeAuthFileRepository([this._file = const OpenCodeAuthFile()]);

  final OpenCodeAuthFile _file;

  @override
  Future<Result<List<OpenCodeCredential>>> listCredentials() async {
    try {
      final entries = await _file.read();
      final credentials = entries.entries.map(_toCredential).toList()
        ..sort((a, b) => a.providerId.compareTo(b.providerId));
      return Ok(credentials);
    } on FormatException catch (e) {
      return Err(_malformed(e));
    } catch (e) {
      return Err(
        StorageFailure('Could not read OpenCode credentials: $e', cause: e),
      );
    }
  }

  @override
  Future<Result<void>> saveApiKey({
    required String providerId,
    required String key,
  }) async {
    final id = providerId.trim();
    final secret = key.trim();
    if (id.isEmpty) {
      return const Err(StorageFailure('Provider is required'));
    }
    if (secret.isEmpty) {
      return const Err(StorageFailure('API key is required'));
    }
    return _mutate(
      (entries) =>
          entries[id] = <String, dynamic>{'type': 'api', 'key': secret},
    );
  }

  @override
  Future<Result<void>> removeCredential(String providerId) =>
      _mutate((entries) => entries.remove(providerId.trim()));

  /// Read–modify–write of the whole file so entries we don't touch (OAuth
  /// logins, other providers) survive the change.
  Future<Result<void>> _mutate(
    void Function(Map<String, dynamic>) change,
  ) async {
    try {
      final entries = await _file.read();
      change(entries);
      await _file.write(entries);
      return const Ok(null);
    } on FormatException catch (e) {
      return Err(_malformed(e));
    } on FileSystemException catch (e) {
      return Err(
        StorageFailure(
          'Could not write OpenCode credentials: ${e.message}',
          cause: e,
        ),
      );
    } catch (e) {
      return Err(
        StorageFailure('Could not write OpenCode credentials: $e', cause: e),
      );
    }
  }

  /// Refuse to guess at a file we can't parse — overwriting it would wipe
  /// working logins.
  ParseFailure _malformed(Object cause) => ParseFailure(
    "OpenCode's credentials file isn't valid JSON — fix it with "
    '`opencode auth login` before changing a key here.',
    cause: cause,
  );

  OpenCodeCredential _toCredential(MapEntry<String, dynamic> entry) {
    final value = entry.value;
    final fields = value is Map<String, dynamic>
        ? value
        : const <String, dynamic>{};
    final type = switch (fields['type']) {
      'api' => OpenCodeAuthType.api,
      'oauth' => OpenCodeAuthType.oauth,
      'wellknown' => OpenCodeAuthType.wellKnown,
      _ => OpenCodeAuthType.unknown,
    };
    return OpenCodeCredential(
      providerId: entry.key,
      type: type,
      keyPreview: type == OpenCodeAuthType.api
          ? _mask(fields['key']?.toString())
          : null,
    );
  }

  /// A recognizable but non-recoverable form of the key: the last four
  /// characters behind a fixed-width mask.
  static String? _mask(String? key) {
    if (key == null || key.isEmpty) return null;
    const dots = '••••••';
    return key.length <= 4 ? dots : '$dots${key.substring(key.length - 4)}';
  }
}
