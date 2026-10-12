import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../providers/sticker_import_jobs.dart';
import 'chat_snack.dart';

/// Says how a background sticker-set import ended — added (and how many
/// stickers are still stand-ins) or failed — wherever the user is by then,
/// as the sticker panel that started it may be long closed.
class StickerImportListener extends ConsumerWidget {
  const StickerImportListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(stickerImportsProvider, (_, jobs) {
      final l = AppL10n.of(context);
      for (final job in jobs.where((j) => j.finished)) {
        if (job.result case final r?) {
          final done = l.stickerImportDone(r.title, r.added);
          showChatSnack(
            context,
            r.stills == 0 ? done : '$done · ${l.stickerImportStills(r.stills)}',
          );
        } else {
          showChatSnack(context, l.stickerImportFailedNamed(job.title));
        }
        // After this notification, not during it.
        scheduleMicrotask(
          () => ref.read(stickerImportsProvider.notifier).dismiss(job.id),
        );
      }
    });
    return child;
  }
}
