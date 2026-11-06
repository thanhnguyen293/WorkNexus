import '../../../../core/error/guard_storage.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/cookie_import.dart';
import '../../domain/repositories/cookie_import_repository.dart';
import '../datasources/cookie_import_store.dart';

/// The imported sites in [CookieImportStore]. Changes follow one another, so
/// two imports at once lose neither.
class LocalCookieImportRepository implements CookieImportRepository {
  LocalCookieImportRepository(this._store);

  final CookieImportStore _store;
  Future<void> _changes = Future.value();

  @override
  Future<Result<List<CookieImport>>> all() =>
      guardStorage('Could not read the cookie imports', _store.read);

  @override
  Future<Result<List<CookieImport>>> save(List<CookieImport> imports) {
    final sites = {for (final i in imports) i.site};
    return _change(
      (items) => [
        for (final item in items)
          if (!sites.contains(item.site)) item,
        ...imports,
      ],
    );
  }

  @override
  Future<Result<List<CookieImport>>> forget(String site) => _change(
    (items) => [
      for (final item in items)
        if (item.site != site) item,
    ],
  );

  Future<Result<List<CookieImport>>> _change(
    List<CookieImport> Function(List<CookieImport>) change,
  ) {
    final done = _changes.then(
      (_) => guardStorage('Could not save the cookie imports', () async {
        final items = change(await _store.read())
          ..sort((a, b) => a.site.compareTo(b.site));
        await _store.write(items);
        return items;
      }),
    );
    _changes = done;
    return done;
  }
}
