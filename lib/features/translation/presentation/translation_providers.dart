import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/domain/entities/translation_record.dart';
import '../../../core/domain/value_objects/translation_state.dart';
import '../../agents/data/cli_agent_adapters.dart';
import '../domain/adapters/translation_service.dart';
import '../domain/usecases/resolve_translation_state.dart';

/// Whether OpenCode is authenticated (`opencode auth login` has been run). When
/// true, translation uses OpenCode's own provider/auth so it shows in usage.
final openCodeAuthedProvider = FutureProvider<bool>(
  (ref) => const AgentRunner().hasOpenCodeAuth(),
);

/// The cached translation record for a ticket (reactive).
final translationRecordProvider =
    StreamProvider.family<TranslationRecord?, String>(
      (ref, ticketId) =>
          ref.watch(translationRepositoryProvider).watchTranslation(ticketId),
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
    final svc = ref.read(translationServiceProvider);
    final res = await svc.translate(
      ticketId: ticketId,
      source: TicketSource(title: ticket.title, body: ticket.body),
      sourceHash: ticket.sourceHash,
    );
    await res.fold(
      (record) async {
        await ref.read(translationRepositoryProvider).saveTranslation(record);
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

/// Resolved translation state + record for a ticket.
final translationStatusProvider =
    Provider.family<
      ({TranslationState state, TranslationRecord? record}),
      String
    >((ref, id) {
      final record = ref.watch(translationRecordProvider(id)).asData?.value;
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
