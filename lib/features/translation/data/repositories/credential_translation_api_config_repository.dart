import 'dart:convert';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/platform/credential_store.dart';
import '../../domain/entities/translation_api_config.dart';
import '../../domain/repositories/translation_api_config_repository.dart';

/// Keeps the whole configuration — key included — as one keychain item, so
/// reading it costs a single OS prompt rather than one per field.
class CredentialTranslationApiConfigRepository
    implements TranslationApiConfigRepository {
  CredentialTranslationApiConfigRepository(this._store);

  static const _ref = 'translation:api';

  final CredentialStore _store;

  /// The last successful read: every translation asks for the configuration,
  /// and each ask would decode the stored JSON again.
  Result<TranslationApiConfig?>? _cached;

  @override
  Future<Result<TranslationApiConfig?>> load() async {
    final cached = _cached;
    if (cached != null) return cached;
    final result = await _read();
    if (result.isOk) _cached = result;
    return result;
  }

  Future<Result<TranslationApiConfig?>> _read() async {
    try {
      final raw = await _store.read(_ref);
      if (raw == null || raw.isEmpty) return const Ok(null);
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return const Ok(null);
      return Ok(
        TranslationApiConfig(
          presetId: json['preset'] as String? ?? 'custom',
          baseUrl: json['baseUrl'] as String? ?? '',
          model: json['model'] as String? ?? '',
          apiKey: json['apiKey'] as String? ?? '',
          enabled: json['enabled'] as bool? ?? true,
        ),
      );
    } on FormatException {
      return const Ok(null);
    } catch (e) {
      return Err(
        StorageFailure('Could not read the translation key', cause: e),
      );
    }
  }

  @override
  Future<Result<void>> save(TranslationApiConfig config) async {
    try {
      await _store.write(
        _ref,
        jsonEncode({
          'preset': config.presetId,
          'baseUrl': config.baseUrl,
          'model': config.model,
          'apiKey': config.apiKey,
          'enabled': config.enabled,
        }),
      );
      _cached = Ok(config);
      return const Ok(null);
    } catch (e) {
      return Err(
        StorageFailure('Could not save the translation key', cause: e),
      );
    }
  }

  @override
  Future<Result<void>> clear() async {
    try {
      await _store.delete(_ref);
      _cached = const Ok(null);
      return const Ok(null);
    } catch (e) {
      return Err(
        StorageFailure('Could not remove the translation key', cause: e),
      );
    }
  }
}
