import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/error/result.dart';
import '../domain/entities/translation_api_config.dart';
import '../domain/repositories/translation_api_config_repository.dart';
import '../domain/repositories/translation_api_model_catalog.dart';

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

/// The endpoint whose models the form lists.
typedef ModelCatalogQuery = ({String baseUrl, String apiKey});

/// The models [ModelCatalogQuery.baseUrl] serves. The form rebuilds this per
/// keystroke in the key field, so the request waits for typing to settle and
/// only the query still being watched reaches the network.
final translationApiModelsProvider = FutureProvider.autoDispose
    .family<Result<List<String>>, ModelCatalogQuery>((ref, query) async {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!ref.mounted) return const Ok([]);
      return getIt<TranslationApiModelCatalog>().listModels(
        baseUrl: query.baseUrl,
        apiKey: query.apiKey,
      );
    });
