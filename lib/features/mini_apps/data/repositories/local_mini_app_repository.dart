import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/mini_app.dart';
import '../../domain/repositories/mini_app_repository.dart';
import '../datasources/favicon_fetcher.dart';
import '../datasources/mini_app_icon_storage.dart';
import '../datasources/mini_app_local_datasource.dart';
import '../mappers/mini_app_mapper.dart';

/// [MiniAppRepository] over the local database and the icon folder.
class LocalMiniAppRepository implements MiniAppRepository {
  const LocalMiniAppRepository(this._local, this._icons, this._favicons);

  final MiniAppLocalDatasource _local;
  final MiniAppIconStorage _icons;
  final FaviconFetcher _favicons;

  @override
  Stream<List<MiniApp>> watchAll() => _local.watchAll().map(
    (rows) => [for (final row in rows) MiniAppMapper.fromRow(row)],
  );

  @override
  Future<Result<void>> save(MiniApp app) =>
      _guard(() => _local.save(MiniAppMapper.toRow(app)));

  @override
  Future<Result<void>> saveLastUrl(String id, String url) =>
      _guard(() => _local.updateLastUrl(id, url));

  @override
  Future<Result<void>> delete(String id) => _guard(() async {
    await _icons.delete(id);
    await _local.delete(id);
  });

  @override
  Future<Result<String?>> fetchSiteIcon({
    required String id,
    required String pageUrl,
  }) => _guard(() async {
    final icon = await _favicons.fetch(Uri.parse(pageUrl));
    if (icon == null) return null;
    return _icons.save(id, icon.bytes, icon.extension);
  });

  @override
  Future<Result<String>> importIcon({
    required String id,
    required String sourcePath,
  }) => _guard(() => _icons.import(id, sourcePath));

  Future<Result<T>> _guard<T>(Future<T> Function() run) async {
    try {
      return Ok(await run());
    } on Exception catch (e) {
      return Err(StorageFailure('Could not keep the mini app', cause: e));
    }
  }
}
