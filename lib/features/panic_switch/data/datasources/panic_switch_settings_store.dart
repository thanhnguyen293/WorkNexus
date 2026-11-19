import '../../../../core/database/app_settings_kv_store.dart';

/// Keeps the panic switch settings as one JSON value in the app's key-value
/// store, so they need no table or migration of their own.
class PanicSwitchSettingsStore {
  PanicSwitchSettingsStore(this._kv);

  static const _key = 'panic_switch.config';

  final AppSettingsKvStore _kv;

  Future<String?> read() => _kv.read(_key);

  Future<void> write(String value) => _kv.write(_key, value);
}
