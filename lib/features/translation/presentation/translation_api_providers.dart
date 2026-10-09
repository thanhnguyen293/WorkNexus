import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/error/result.dart';
import '../domain/entities/translation_api_config.dart';
import '../domain/repositories/translation_api_config_repository.dart';

/// The saved "translate with my own API key" setup; null when there is none.
final translationApiConfigProvider =
    FutureProvider.autoDispose<Result<TranslationApiConfig?>>(
      (ref) => getIt<TranslationApiConfigRepository>().load(),
    );

/// Saves and clears the setup, refreshing [translationApiConfigProvider].
class TranslationApiController extends Notifier<void> {
  @override
  void build() {}

  Future<Result<void>> save(TranslationApiConfig config) async {
    final result = await getIt<TranslationApiConfigRepository>().save(config);
    ref.invalidate(translationApiConfigProvider);
    return result;
  }

  Future<Result<void>> clear() async {
    final result = await getIt<TranslationApiConfigRepository>().clear();
    ref.invalidate(translationApiConfigProvider);
    return result;
  }
}

final translationApiControllerProvider =
    NotifierProvider<TranslationApiController, void>(
      TranslationApiController.new,
    );
