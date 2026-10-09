import '../../../../core/error/result.dart';
import '../entities/translation_api_config.dart';

abstract class TranslationApiConfigRepository {
  /// The saved configuration; null when none was set up.
  Future<Result<TranslationApiConfig?>> load();

  Future<Result<void>> save(TranslationApiConfig config);

  Future<Result<void>> clear();
}
