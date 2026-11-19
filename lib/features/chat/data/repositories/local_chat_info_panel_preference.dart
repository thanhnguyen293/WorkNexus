import '../../../../core/database/app_settings_kv_store.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/repositories/chat_info_panel_preference.dart';

/// [ChatInfoPanelPreference] in the local `app_settings_kv` table: a layout
/// choice for this device's window, so it is not synced with the settings.
class LocalChatInfoPanelPreference implements ChatInfoPanelPreference {
  const LocalChatInfoPanelPreference(this._store);

  static const _key = 'chat.info_panel_visible';

  final AppSettingsKvStore _store;

  @override
  Future<Result<bool>> isVisible() async {
    try {
      return Ok(await _store.read(_key) != 'false');
    } on Object catch (e) {
      return Err(
        StorageFailure('Could not read the chat info choice', cause: e),
      );
    }
  }

  @override
  Future<Result<void>> setVisible(bool visible) async {
    try {
      await _store.write(_key, '$visible');
      return const Ok(null);
    } on Object catch (e) {
      return Err(
        StorageFailure('Could not save the chat info choice', cause: e),
      );
    }
  }
}
