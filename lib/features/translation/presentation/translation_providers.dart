import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/domain/entities/translation_record.dart';
import '../../../core/domain/repositories/translation_repository.dart';
import '../../../core/domain/value_objects/translation_state.dart';
import '../../../core/settings/app_settings.dart';
import '../../agents/data/cli_agent_adapters.dart';
import '../domain/adapters/translation_service.dart';
import '../domain/usecases/resolve_translation_state.dart';

/// Whether OpenCode is authenticated (`opencode auth login` has been run). When
/// true, translation uses OpenCode's own provider/auth so it shows in usage.
final openCodeAuthedProvider = FutureProvider<bool>(
  (ref) => const AgentRunner().hasOpenCodeAuth(),
);

/// The cached translation record for a ticket (reactive). The DB holds one
/// record per ticket; [translationStatusProvider] decides whether it matches the
/// currently-selected target language.
final translationRecordProvider =
    StreamProvider.family<TranslationRecord?, String>(
      (ref, ticketId) =>
          getIt<TranslationRepository>().watchTranslation(ticketId),
    );

/// Transient UI state (in-flight / last error) for one ticket's translation.
class TranslationUiState {
  const TranslationUiState({this.loading = false, this.error});
  final bool loading;
  final String? error;
}

/// Holds per-ticket transient translation state and runs the translate action.
class TranslationController extends Notifier<Map<String, TranslationUiState>> {
  @override
  Map<String, TranslationUiState> build() => const {};

  TranslationUiState stateFor(String ticketId) =>
      state[ticketId] ?? const TranslationUiState();

  Future<void> translate(String ticketId, {bool force = false}) async {
    final ticket = ref.read(ticketByIdProvider(ticketId));
    if (ticket == null) return;
    _set(ticketId, const TranslationUiState(loading: true));
    final svc = getIt<TranslationService>();
    final res = await svc.translate(
      ticketId: ticketId,
      source: TicketSource(title: ticket.title, body: ticket.body),
      sourceHash: ticket.sourceHash,
      targetLang: ref.read(appSettingsProvider).translationLang,
    );
    await res.fold(
      (record) async {
        await getIt<TranslationRepository>().saveTranslation(record);
        _set(ticketId, const TranslationUiState());
      },
      (failure) async {
        _set(ticketId, TranslationUiState(error: failure.message));
      },
    );
  }

  void _set(String ticketId, TranslationUiState value) =>
      state = {...state, ticketId: value};
}

final translationControllerProvider =
    NotifierProvider<TranslationController, Map<String, TranslationUiState>>(
      TranslationController.new,
    );

/// Resolved translation state + record for a ticket, scoped to the currently
/// selected target language. A cached record in a *different* language is
/// treated as "not translated" so switching languages prompts a fresh run
/// rather than showing the wrong-language text.
final translationStatusProvider =
    Provider.family<
      ({TranslationState state, TranslationRecord? record}),
      String
    >((ref, id) {
      final targetLang = ref.watch(
        appSettingsProvider.select((s) => s.translationLang),
      );
      final cached = ref.watch(translationRecordProvider(id)).asData?.value;
      // Only surface the cached record when it matches the selected language.
      final record = cached?.targetLang == targetLang ? cached : null;
      final ui =
          ref.watch(translationControllerProvider)[id] ??
          const TranslationUiState();
      final ticket = ref.watch(ticketByIdProvider(id));
      final state = const ResolveTranslationState()(
        currentSourceHash: ticket?.sourceHash ?? '',
        record: record,
        loading: ui.loading,
        hasError: ui.error != null,
      );
      return (state: state, record: record);
    });
