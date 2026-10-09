import '../../../../core/error/result.dart';
import '../entities/cache_section.dart';

/// The device's copy of server-synced data.
abstract class LocalCacheRepository {
  /// Deletes the cached data of [sections]; it downloads again on next sync.
  Future<Result<void>> clear(Set<CacheSection> sections);
}
