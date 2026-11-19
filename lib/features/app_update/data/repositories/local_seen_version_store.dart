import '../../../../core/database/app_settings_kv_store.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/repositories/seen_version_store.dart';

/// [SeenVersionStore] in the local `app_settings_kv` table.
class LocalSeenVersionStore implements SeenVersionStore {
  const LocalSeenVersionStore(this._store);

  static const _key = 'app_update.last_seen_version';

  final AppSettingsKvStore _store;

  @override
  Future<Result<String?>> lastSeen() async {
    try {
      return Ok(await _store.read(_key));
    } on Object catch (e) {
      return Err(StorageFailure('Could not read the last version', cause: e));
    }
  }

  @override
  Future<Result<void>> setLastSeen(String version) async {
    try {
      await _store.write(_key, version);
      return const Ok(null);
    } on Object catch (e) {
      return Err(StorageFailure('Could not save the version', cause: e));
    }
  }
}
