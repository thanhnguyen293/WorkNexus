import '../../../../core/error/guard_storage.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/mini_app.dart';
import '../../domain/repositories/mini_app_repository.dart';
import '../datasources/mini_app_icon_store.dart';
import '../datasources/mini_app_local_datasource.dart';
import '../datasources/site_icon_source.dart';
import '../mappers/mini_app_mapper.dart';

/// [MiniAppRepository] over the local database, an icon store and the site
/// the icon comes from.
class LocalMiniAppRepository implements MiniAppRepository {
  const LocalMiniAppRepository(this._local, this._icons, this._siteIcons);

  final MiniAppLocalDatasource _local;
  final MiniAppIconStore _icons;
  final SiteIconSource _siteIcons;

  static const _failure = 'Could not keep the mini app';

  @override
  Stream<List<MiniApp>> watchAll() => _local.watchAll().map(
    (rows) => [for (final row in rows) MiniAppMapper.fromRow(row)],
  );

  @override
  Future<Result<void>> save(MiniApp app) =>
      guardStorage(_failure, () => _local.save(MiniAppMapper.toRow(app)));

  @override
  Future<Result<void>> saveLastUrl(String id, String url) =>
      guardStorage(_failure, () => _local.updateLastUrl(id, url));

  @override
  Future<Result<void>> delete(String id) => guardStorage(_failure, () async {
    await _icons.delete(id);
    await _local.delete(id);
  });

  @override
  Future<Result<String?>> fetchSiteIcon({
    required String id,
    required String pageUrl,
  }) => guardStorage(_failure, () async {
    final icon = await _siteIcons.fetch(Uri.parse(pageUrl));
    if (icon == null) return null;
    return _icons.save(id, icon.bytes, icon.extension);
  });

  @override
  Future<Result<String>> importIcon({
    required String id,
    required String sourcePath,
  }) => guardStorage(_failure, () => _icons.import(id, sourcePath));
}
