import '../../../../core/error/result.dart';
import '../repositories/seen_version_store.dart';
import '../repositories/update_repository.dart';
import '../value_objects/app_version.dart';
import 'collect_release_notes.dart';

/// What the running version brought since the one this computer ran last.
typedef WhatsNew = ({String from, String to, String notes});

/// At launch: the notes of every release since the last version seen, when
/// the app was just updated; null otherwise (first launch, same version, or
/// nothing written for those releases). The running version is remembered
/// once the notes are known, so a failed fetch is tried again next launch.
class FindWhatsNew {
  const FindWhatsNew(this._releases, this._seen);

  final UpdateRepository _releases;
  final SeenVersionStore _seen;

  Future<Result<WhatsNew?>> call() async {
    final current = await _releases.currentVersion();
    final seen = await _seen.lastSeen();
    if (seen case Err(:final failure)) return Err(failure);
    final last = seen.valueOrNull;
    final from = last == null ? null : AppVersion.parse(last);
    final to = AppVersion.parse(current);
    if (last == null || from == null || to == null || to.compareTo(from) <= 0) {
      // First launch, a downgrade or the same build: nothing to tell.
      if (last != current) return _remember(current, null);
      return const Ok(null);
    }
    final collected = await CollectReleaseNotes(_releases)(
      after: last,
      upTo: current,
    );
    if (collected case Err(:final failure)) return Err(failure);
    final notes = collected.valueOrNull ?? '';
    return _remember(
      current,
      notes.isEmpty ? null : (from: last, to: current, notes: notes),
    );
  }

  Future<Result<WhatsNew?>> _remember(String version, WhatsNew? news) async =>
      switch (await _seen.setLastSeen(version)) {
        Ok() => Ok(news),
        Err(:final failure) => Err(failure),
      };
}
