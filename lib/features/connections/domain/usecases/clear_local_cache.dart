import '../../../../core/error/result.dart';
import '../entities/cache_section.dart';
import '../repositories/local_cache_repository.dart';

class ClearLocalCache {
  const ClearLocalCache(this._repository);

  final LocalCacheRepository _repository;

  /// Nothing picked is nothing to do.
  Future<Result<void>> call(Set<CacheSection> sections) async =>
      sections.isEmpty ? const Ok(null) : _repository.clear(sections);
}
