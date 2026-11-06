import '../../../../core/error/result.dart';
import '../entities/cookie_import.dart';

/// The sites whose cookies were imported, one entry per site. Each change
/// answers with the list as it now is.
abstract interface class CookieImportRepository {
  Future<Result<List<CookieImport>>> all();

  /// Keeps [imports], replacing the entries of the same sites.
  Future<Result<List<CookieImport>>> save(List<CookieImport> imports);

  Future<Result<List<CookieImport>>> forget(String site);
}
