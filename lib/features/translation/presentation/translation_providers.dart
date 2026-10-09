import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/domain/adapters/opencode_cli.dart';
import '../../../core/domain/entities/translation_record.dart';
import '../../../core/domain/repositories/translation_repository.dart';
import '../../../core/domain/value_objects/translation_state.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/util/body_format.dart';
import '../../../core/util/html_to_markdown.dart';
import '../domain/adapters/translation_service.dart';
import '../domain/usecases/resolve_translation_state.dart';

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

  /// Tickets whose in-flight run the user cancelled. The pending future still
  /// resolves (with a failure) — this is how we tell "the user stopped it" from
  /// "it broke", so a cancel leaves no error banner behind.
  final Set<String> _cancelled = <String>{};

  Future<void> translate(String ticketId, {bool force = false}) async {
    final ticket = ref.read(ticketByIdProvider(ticketId));
    if (ticket == null) return;
    _cancelled.remove(ticketId);
    _set(ticketId, const TranslationUiState(loading: true));
    final settings = ref.read(appSettingsProvider);
    final svc = getIt<TranslationService>();
    final res = await svc.translate(
      ticketId: ticketId,
      // Sent and translated as Markdown, whatever the source's format.
      source: TicketSource(
        title: ticket.title,
        body: isHtmlBody(ticket.providerType, ticket.body)
            ? htmlToMarkdown(ticket.body)
            : ticket.body,
      ),
      sourceHash: ticket.sourceHash,
      targetLang: settings.translationLang,
      model: settings.translationModel.isEmpty
          ? null
          : settings.translationModel,
    );
    if (_cancelled.remove(ticketId)) {
      _set(ticketId, const TranslationUiState());
      return;
    }
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

  /// Stops the in-flight translation for [ticketId] and drops back to idle.
  Future<void> cancel(String ticketId) async {
    if (!stateFor(ticketId).loading) return;
    _cancelled.add(ticketId);
    await getIt<TranslationService>().cancel(ticketId);
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

/// The `provider/model` ids OpenCode can translate with, for the Settings
/// picker. Empty when the CLI can't be asked, in which case the picker says so
/// and keeps whatever model is already pinned.
///
/// Cached for the session (no `autoDispose`) on purpose: asking the CLI spawns a
/// subprocess that takes seconds, and the installed model list doesn't change
/// while the app is open — re-running it on every visit to Settings would make
/// the page feel broken. Widget tests override this so they never shell out.
final openCodeModelsProvider = FutureProvider<List<String>>(
  (ref) => getIt<OpenCodeCli>().listModels(),
);
