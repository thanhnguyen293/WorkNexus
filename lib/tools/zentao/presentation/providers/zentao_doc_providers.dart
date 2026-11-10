import 'package:flutter/foundation.dart' show Brightness;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/zentao_doc.dart';
import '../../domain/entities/zentao_doc_lib.dart';
import '../../domain/entities/zentao_doc_pins.dart';
import '../../domain/entities/zentao_doc_summary.dart';
import '../../domain/repositories/zentao_doc_repository.dart';
import '../../domain/usecases/refresh_zentao_doc.dart';
import '../../domain/usecases/refresh_zentao_doc_libs.dart';
import '../../domain/usecases/refresh_zentao_docs.dart';

final zenTaoDocRepositoryProvider = Provider<ZenTaoDocRepository>(
  (ref) => getIt<ZenTaoDocRepository>(),
);

/// An account's cached document libraries.
final zentaoDocLibsProvider = StreamProvider.autoDispose
    .family<List<ZenTaoDocLib>, String>(
      (ref, accountId) =>
          ref.watch(zenTaoDocRepositoryProvider).watchLibs(accountId),
    );

typedef ZenTaoDocListKey = ({String accountId, String libId});

/// One library's cached document list.
final zentaoDocsProvider = StreamProvider.autoDispose
    .family<List<ZenTaoDocSummary>, ZenTaoDocListKey>(
      (ref, key) => ref
          .watch(zenTaoDocRepositoryProvider)
          .watchDocs(key.accountId, key.libId),
    );

typedef ZenTaoDocKey = ({String accountId, String docId});

/// One cached document; null until it was fetched.
final zentaoDocProvider = StreamProvider.autoDispose
    .family<ZenTaoDoc?, ZenTaoDocKey>(
      (ref, key) => ref
          .watch(zenTaoDocRepositoryProvider)
          .watchDoc(key.accountId, key.docId),
    );

/// What a [ZenTaoDocSync] fetches: an account's libraries (no [libId] and no
/// [docId]), one library's documents ([libId]), or one document ([docId]).
typedef ZenTaoDocSyncKey = ({Account account, String? libId, String? docId});

/// Fetches into the cache when first watched; [ZenTaoDocSync.refresh] fetches
/// again. The cached rows render meanwhile, so a failure here is shown beside
/// them rather than in their place.
final zentaoDocSyncProvider = AsyncNotifierProvider.autoDispose
    .family<ZenTaoDocSync, void, ZenTaoDocSyncKey>(ZenTaoDocSync.new);

class ZenTaoDocSync extends AsyncNotifier<void> {
  ZenTaoDocSync(this.key);

  final ZenTaoDocSyncKey key;

  @override
  Future<void> build() => _run();

  Future<void> refresh() async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(_run);
  }

  Future<void> _run() async {
    final Result<void> res;
    if (key.docId case final docId?) {
      res = await getIt<RefreshZenTaoDoc>()(key.account, docId);
    } else if (key.libId case final libId?) {
      res = await getIt<RefreshZenTaoDocs>()(key.account, libId);
    } else {
      res = await getIt<RefreshZenTaoDocLibs>()(key.account);
    }
    if (res case Err(:final failure)) throw ZenTaoDocSyncException(failure);
  }
}

/// A failed document fetch, carrying why.
class ZenTaoDocSyncException implements Exception {
  const ZenTaoDocSyncException(this.failure);

  final Failure failure;
}

/// The document open in each library, by library id; kept for the session so
/// going back to a library shows the document read last.
final zentaoOpenDocProvider =
    NotifierProvider<ZenTaoOpenDocs, Map<String, String>>(ZenTaoOpenDocs.new);

class ZenTaoOpenDocs extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() => const {};

  void open(String libId, String docId) => state = {...state, libId: docId};
}

/// The light / dark look the document reader is forced to, or null to
/// follow the app's theme. Kept for the session: a dark app may read a long
/// document on light, as ZenTao's web shows it.
final zentaoDocReaderBrightnessProvider =
    NotifierProvider<ZenTaoDocReaderBrightness, Brightness?>(
      ZenTaoDocReaderBrightness.new,
    );

class ZenTaoDocReaderBrightness extends Notifier<Brightness?> {
  @override
  Brightness? build() => null;

  /// Flips the reader from what it shows ([current]); landing back on the
  /// app's own brightness ([app]) follows the app again.
  void toggle({required Brightness current, required Brightness app}) {
    final next = current == Brightness.dark
        ? Brightness.light
        : Brightness.dark;
    state = next == app ? null : next;
  }
}

/// An account's pinned libraries and documents.
final zentaoDocPinsProvider = StreamProvider.autoDispose
    .family<ZenTaoDocPins, String>(
      (ref, accountId) =>
          ref.watch(zenTaoDocRepositoryProvider).watchPins(accountId),
    );

/// The libraries opened in the Docs tree, as `accountId|libId`; kept for the
/// session so coming back to Docs shows the tree as it was left.
final zentaoDocExpandedLibsProvider =
    NotifierProvider<ZenTaoDocExpandedLibs, Set<String>>(
      ZenTaoDocExpandedLibs.new,
    );

class ZenTaoDocExpandedLibs extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  static String keyOf(String accountId, String libId) => '$accountId|$libId';

  void toggle(String accountId, String libId) {
    final key = keyOf(accountId, libId);
    state = state.contains(key)
        ? {
            for (final k in state)
              if (k != key) k,
          }
        : {...state, key};
  }

  void expand(String accountId, String libId) {
    final key = keyOf(accountId, libId);
    if (!state.contains(key)) state = {...state, key};
  }
}
