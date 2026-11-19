import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/panic_switch_config.dart';
import '../../domain/repositories/panic_switch_config_repository.dart';
import '../datasources/panic_switch_settings_store.dart';
import '../mappers/panic_switch_config_mapper.dart';

class LocalPanicSwitchConfigRepository implements PanicSwitchConfigRepository {
  LocalPanicSwitchConfigRepository(this._store);

  final PanicSwitchSettingsStore _store;

  @override
  Future<Result<PanicSwitchConfig>> load() async {
    try {
      final json = await _store.read();
      return Ok(
        json == null
            ? const PanicSwitchConfig()
            : PanicSwitchConfigMapper.fromJson(json),
      );
    } on Object catch (e) {
      return Err(
        StorageFailure('Could not read the panic switch settings', cause: e),
      );
    }
  }

  @override
  Future<Result<void>> save(PanicSwitchConfig config) async {
    try {
      await _store.write(PanicSwitchConfigMapper.toJson(config));
      return const Ok(null);
    } on Object catch (e) {
      return Err(
        StorageFailure('Could not save the panic switch settings', cause: e),
      );
    }
  }
}
