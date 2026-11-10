import 'dart:async';

import 'package:flutter/foundation.dart' show Brightness;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/locator.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/settings/app_settings.dart';
import '../../domain/entities/zentao_doc.dart';
import '../../domain/entities/zentao_doc_action.dart';
import '../../domain/entities/zentao_doc_lib.dart';
import '../../domain/entities/zentao_doc_pins.dart';
import '../../domain/entities/zentao_doc_summary.dart';
import '../../domain/repositories/zentao_doc_repository.dart';
import '../../domain/usecases/export_zentao_doc.dart';
import '../../domain/usecases/refresh_zentao_doc.dart';
import '../../domain/usecases/refresh_zentao_doc_history.dart';
import '../../domain/usecases/refresh_zentao_doc_libs.dart';
import '../../domain/usecases/refresh_zentao_docs.dart';

final zenTaoDocRepositoryProvider = Provider<ZenTaoDocRepository>(
  (ref) => getIt<ZenTaoDocRepository>(),
);

final exportZenTaoDocProvider = Provider<ExportZenTaoDoc>(
  (ref) => getIt<ExportZenTaoDoc>(),
);

// The tree's cache reads stay alive: the nav pane is rebuilt on every trip
// to Tasks or Bugs (only the viewport keeps its sections), and a fresh
// subscription has no rows for a frame — the tree would flash "Loading" and
// lose its scroll position. They are cheap local watches, one per account
// or opened library.

/// An account's cached document libraries.
final zentaoDocLibsProvider = StreamProvider.family<List<ZenTaoDocLib>, String>(
  (ref, accountId) =>
      ref.watch(zenTaoDocRepositoryProvider).watchLibs(accountId),
);

typedef ZenTaoDocListKey = ({String accountId, String libId});

/// One library's cached document list.
final zentaoDocsProvider =
    StreamProvider.family<List<ZenTaoDocSummary>, ZenTaoDocListKey>(
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
/// them rather than in their place. Kept for [ZenTaoDocSync.idleLife] once
/// nothing watches it, so leaving Docs for a moment doesn't refetch the
/// libraries and every opened library on return.
final zentaoDocSyncProvider = AsyncNotifierProvider.autoDispose
    .family<ZenTaoDocSync, void, ZenTaoDocSyncKey>(ZenTaoDocSync.new);

class ZenTaoDocSync extends AsyncNotifier<void> {
  ZenTaoDocSync(this.key);

  final ZenTaoDocSyncKey key;

  /// How long a fetch stays fresh with nothing watching it.
  static const idleLife = Duration(minutes: 10);

  @override
  Future<void> build() {
    final link = ref.keepAlive();
    Timer? expiry;
    ref
      ..onCancel(() => expiry = Timer(idleLife, link.close))
      ..onResume(() => expiry?.cancel())
      ..onDispose(() => expiry?.cancel());
    return _run();
  }

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

/// The document open in the reader, as its library and id.
typedef ZenTaoOpenDoc = ({String libId, String docId});

/// The document open for each account, kept for the session apart from the
/// location's scope — which a trip to Tasks or Bugs clears — so coming back
/// to Docs shows the document left open.
final zentaoOpenDocProvider =
    NotifierProvider<ZenTaoOpenDocs, Map<String, ZenTaoOpenDoc>>(
      ZenTaoOpenDocs.new,
    );

class ZenTaoOpenDocs extends Notifier<Map<String, ZenTaoOpenDoc>> {
  @override
  Map<String, ZenTaoOpenDoc> build() => const {};

  void open(String accountId, String libId, String docId) =>
      state = {...state, accountId: (libId: libId, docId: docId)};
}

/// The Docs tree's filter text per account, kept for the session.
final zentaoDocFilterProvider =
    NotifierProvider<ZenTaoDocFilters, Map<String, String>>(
      ZenTaoDocFilters.new,
    );

class ZenTaoDocFilters extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() => const {};

  void set(String accountId, String text) =>
      state = {...state, accountId: text};
}

/// The light / dark look the document reader is forced to, or null to
/// follow the app's theme: a dark app may read a long document on light, as
/// ZenTao's web shows it. Kept in the app's settings, so the choice survives
/// a restart.
final zentaoDocReaderBrightnessProvider =
    NotifierProvider<ZenTaoDocReaderBrightness, Brightness?>(
      ZenTaoDocReaderBrightness.new,
    );

class ZenTaoDocReaderBrightness extends Notifier<Brightness?> {
  @override
  Brightness? build() =>
      ref.watch(appSettingsProvider.select((s) => s.docsReaderBrightness));

  /// Flips the reader from what it shows ([current]); landing back on the
  /// app's own brightness ([app]) follows the app again.
  void toggle({required Brightness current, required Brightness app}) {
    final next = current == Brightness.dark
        ? Brightness.light
        : Brightness.dark;
    ref
        .read(appSettingsProvider.notifier)
        .setDocsReaderBrightness(next == app ? null : next);
  }
}

/// An account's pinned libraries and documents.
final zentaoDocPinsProvider = StreamProvider.family<ZenTaoDocPins, String>(
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

/// A document's cached history, oldest first.
final zentaoDocHistoryProvider = StreamProvider.autoDispose
    .family<List<ZenTaoDocAction>, ZenTaoDocKey>(
      (ref, key) => ref
          .watch(zenTaoDocRepositoryProvider)
          .watchHistory(key.accountId, key.docId),
    );

typedef ZenTaoDocHistoryKey = ({Account account, String docId});

/// Fetches a document's history into the cache while its panel is open;
/// invalidate it to fetch again.
final zentaoDocHistorySyncProvider = FutureProvider.autoDispose
    .family<void, ZenTaoDocHistoryKey>((ref, key) async {
      final res = await getIt<RefreshZenTaoDocHistory>()(
        key.account,
        key.docId,
      );
      if (res case Err(:final failure)) throw ZenTaoDocSyncException(failure);
    });
