import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/usecases/import_sticker_pack.dart';
import '../../domain/usecases/parse_sticker_pack_link.dart';
import 'sticker_providers.dart';

part 'sticker_import_jobs.freezed.dart';

/// A Telegram set being imported in the background, until its outcome has
/// been shown.
@freezed
abstract class StickerImportJob with _$StickerImportJob {
  const StickerImportJob._();

  const factory StickerImportJob({
    /// The set's name, from its link.
    required String id,
    required String title,
    required int total,
    @Default(0) int done,
    ImportedStickerPack? result,
    Failure? failure,
  }) = _StickerImportJob;

  bool get finished => result != null || failure != null;
}

/// Imports run here rather than in the dialog, so closing it — or the
/// sticker panel — does not stop one. Kept for the app's lifetime.
class StickerImportsController extends Notifier<List<StickerImportJob>> {
  @override
  List<StickerImportJob> build() => const [];

  /// Starts importing the set at [link]. Resolves once Telegram has listed
  /// it (the link and token are good; the rest goes on in the background)
  /// to its title, or to why it cannot be imported.
  Future<Result<String>> start(String link, {required String token}) {
    final id = const ParseStickerPackLink()(link) ?? link.trim();
    if (state.where((j) => j.id == id && !j.finished).firstOrNull
        case final running?) {
      return Future.value(Ok(running.title));
    }
    final listed = Completer<Result<String>>();
    final importer = ref.read(telegramStickerImporterProvider);
    unawaited(
      importer
          .import(
            link,
            token: token,
            onListed: (title, total) {
              _put(StickerImportJob(id: id, title: title, total: total));
              listed.complete(Ok(title));
            },
            onProgress: (done, _) =>
                _update(id, (job) => job.copyWith(done: done)),
          )
          .then((result) {
            switch (result) {
              case Ok(:final value):
                _update(id, (job) => job.copyWith(result: value));
              case Err(:final failure) when !listed.isCompleted:
                listed.complete(Err(failure));
              case Err(:final failure):
                _update(id, (job) => job.copyWith(failure: failure));
            }
          }),
    );
    return listed.future;
  }

  /// Forgets a finished import once its outcome has been shown.
  void dismiss(String id) => state = [
    for (final job in state)
      if (job.id != id) job,
  ];

  void _put(StickerImportJob job) => state = [
    for (final j in state)
      if (j.id != job.id) j,
    job,
  ];

  void _update(String id, StickerImportJob Function(StickerImportJob) change) {
    if (!ref.mounted) return;
    state = [for (final job in state) job.id == id ? change(job) : job];
  }
}

final stickerImportsProvider =
    NotifierProvider<StickerImportsController, List<StickerImportJob>>(
      StickerImportsController.new,
    );
