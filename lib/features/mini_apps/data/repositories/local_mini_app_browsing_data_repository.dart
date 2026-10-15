import '../../../../core/error/failure.dart';
import '../../../../core/error/guard_storage.dart';
import '../../../../core/error/result.dart';
import '../../domain/repositories/mini_app_browsing_data_repository.dart';
import '../datasources/web_profile_datasource.dart';

/// [MiniAppBrowsingDataRepository] over the web view's own profile.
class LocalMiniAppBrowsingDataRepository
    implements MiniAppBrowsingDataRepository {
  const LocalMiniAppBrowsingDataRepository(this._profile);

  final WebProfileDatasource _profile;

  static const _failure = 'Could not clear the browsing data';

  @override
  bool get canClear => _profile.supported;

  @override
  Future<Result<void>> clearCache() => _guard(_profile.clearCache);

  @override
  Future<Result<void>> clearSite(String url) =>
      _guard(() => _profile.clearOrigins(_origins([url])));

  @override
  Future<Result<void>> clearAll(List<String> urls) => _guard(() async {
    await _profile.clearCookies();
    await _profile.clearOrigins(_origins(urls));
    await _profile.clearCache();
  });

  /// The web origins of [urls]; anything that is not a web address is skipped.
  static List<String> _origins(List<String> urls) => [
    for (final url in urls)
      if (Uri.tryParse(url) case final uri?
          when (uri.scheme == 'http' || uri.scheme == 'https') &&
              uri.host.isNotEmpty)
        uri.origin,
  ];

  Future<Result<void>> _guard(Future<void> Function() job) {
    if (!canClear) {
      return Future.value(const Err(StorageFailure('Not supported here')));
    }
    return guardStorage(_failure, job);
  }
}
