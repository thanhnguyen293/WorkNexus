import '../../../../core/database/app_settings_kv_store.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/repositories/auto_reply_suggestions_preference.dart';

/// [AutoReplySuggestionsPreference] in the local `app_settings_kv` table:
/// it spends this device's AI calls, so it is not synced with the settings.
class LocalAutoReplySuggestionsPreference
    implements AutoReplySuggestionsPreference {
  const LocalAutoReplySuggestionsPreference(this._store);

  static const _key = 'chat.auto_reply_suggestions';

  final AppSettingsKvStore _store;

  @override
  Future<Result<bool>> isEnabled() async {
    try {
      return Ok(await _store.read(_key) == 'true');
    } on Object catch (e) {
      return Err(
        StorageFailure('Could not read the reply ideas choice', cause: e),
      );
    }
  }

  @override
  Future<Result<void>> setEnabled(bool enabled) async {
    try {
      await _store.write(_key, '$enabled');
      return const Ok(null);
    } on Object catch (e) {
      return Err(
        StorageFailure('Could not save the reply ideas choice', cause: e),
      );
    }
  }
}
