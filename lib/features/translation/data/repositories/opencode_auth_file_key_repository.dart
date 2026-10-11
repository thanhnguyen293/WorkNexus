import 'dart:io';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/opencode_provider_auth.dart';
import '../../domain/repositories/opencode_key_repository.dart';
import '../datasources/opencode_auth_file.dart';

/// [OpenCodeKeyRepository] backed by OpenCode's own `auth.json`: saving is the
/// programmatic equivalent of `opencode auth login`, so usage stays on the
/// user's own account.
class OpenCodeAuthFileKeyRepository implements OpenCodeKeyRepository {
  const OpenCodeAuthFileKeyRepository([this._file = const OpenCodeAuthFile()]);

  final OpenCodeAuthFile _file;

  @override
  Future<Result<OpenCodeProviderAuth>> authFor(String providerId) async {
    try {
      final entry = (await _file.read())[providerId.trim()];
      if (entry == null) return const Ok(OpenCodeProviderAuth.none);
      final fields = entry is Map<String, dynamic>
          ? entry
          : const <String, dynamic>{};
      return Ok(
        OpenCodeProviderAuth(
          linked: true,
          keyPreview: fields['type'] == 'api'
              ? _mask(fields['key']?.toString())
              : null,
        ),
      );
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
    if (id.isEmpty || secret.isEmpty) {
      return const Err(StorageFailure('Provider and API key are required'));
    }
    try {
      // Read–modify–write of the whole file so entries we don't touch (OAuth
      // logins, other providers) survive the change.
      final entries = await _file.read();
      entries[id] = <String, dynamic>{'type': 'api', 'key': secret};
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
  static ParseFailure _malformed(Object cause) => ParseFailure(
    "OpenCode's credentials file isn't valid JSON — fix it with "
    '`opencode auth login` before saving a key here.',
    cause: cause,
  );

  /// Recognizable but not recoverable: the last four characters behind a
  /// fixed-width mask.
  static String? _mask(String? key) {
    if (key == null || key.isEmpty) return null;
    const dots = '••••••';
    return key.length <= 4 ? dots : '$dots${key.substring(key.length - 4)}';
  }
}
