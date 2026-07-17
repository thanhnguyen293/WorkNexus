import '../../../../core/domain/entities/translation_record.dart';
import '../../../../core/domain/value_objects/translation_state.dart';

/// Pure state-machine resolver for a ticket's translation, per the plan:
///   loading           → a request is in flight
///   no record, no err  → none
///   no record, error   → error
///   record, hash match → done
///   record, hash diff  → outdated  (show stale translation)
class ResolveTranslationState {
  const ResolveTranslationState();

  TranslationState call({
    required String currentSourceHash,
    TranslationRecord? record,
    bool loading = false,
    bool hasError = false,
  }) {
    if (loading) return TranslationState.loading;
    if (record == null) {
      return hasError ? TranslationState.error : TranslationState.none;
    }
    return record.sourceHash == currentSourceHash
        ? TranslationState.done
        : TranslationState.outdated;
  }
}
