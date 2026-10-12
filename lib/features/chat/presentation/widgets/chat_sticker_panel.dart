import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_confirm_dialog.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_sticker.dart';
import '../providers/sticker_import_jobs.dart';
import '../providers/sticker_providers.dart';
import 'chat_snack.dart';
import 'chat_sticker_grid.dart';
import 'chat_sticker_pack_bar.dart';
import 'import_sticker_pack_dialog.dart';
import 'sticker_import_listener.dart';

/// The sticker tab: one set's grid at a time, picked from the pack bar
/// below — the user's own, imported Telegram sets, then the bundled ones.
/// Opens on the set last picked from; before any (or once it is gone), on
/// the user's own stickers, or the first other set while they have none.
class ChatStickerPanel extends ConsumerStatefulWidget {
  const ChatStickerPanel({
    super.key,
    required this.stickers,
    required this.onPick,
  });

  /// Every sticker: bundled sets and the user's own.
  final List<ChatSticker> stickers;
  final ValueChanged<ChatSticker> onPick;

  @override
  ConsumerState<ChatStickerPanel> createState() => _ChatStickerPanelState();
}

class _ChatStickerPanelState extends ConsumerState<ChatStickerPanel> {
  /// The set shown; '' is the user's own. Null until the user picks one.
  String? _pack;

  void _select(String pack) {
    setState(() => _pack = pack);
    ref.read(lastStickerPackProvider.notifier).remember(pack);
  }

  void _pick(ChatSticker sticker) {
    ref.read(lastStickerPackProvider.notifier).remember(sticker.pack);
    widget.onPick(sticker);
  }

  Future<void> _add() async {
    _select('');
    await addStickersFromImages(context, ref);
  }

  /// The rest of the import runs in the background (see
  /// [StickerImportListener] for its outcome).
  Future<void> _import() async {
    final l = AppL10n.of(context);
    final title = await ImportStickerPackDialog.show(context);
    if (title == null || !mounted) return;
    showChatSnack(context, l.stickerImportStarted(title));
  }

  Future<void> _remove(ChatStickerPackCover pack) async {
    final l = AppL10n.of(context);
    final confirmed = await AppConfirmDialog.show(
      context,
      title: l.stickerPackRemoveTitle(pack.title ?? pack.pack),
      message: l.stickerPackRemoveMessage,
      confirmLabel: l.stickerPackRemove,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final result = await ref
        .read(stickerControllerProvider)
        .removePack(pack.pack);
    if (!mounted) return;
    switch (result) {
      case Ok():
        if (_pack == pack.pack) setState(() => _pack = null);
      case Err(:final failure):
        showChatFailure(context, failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mine = <ChatSticker>[];
    final imported = <String, List<ChatSticker>>{};
    final bundled = <String, List<ChatSticker>>{};
    for (final sticker in widget.stickers) {
      if (sticker.custom && sticker.pack.isEmpty) {
        mine.add(sticker);
      } else {
        ((sticker.custom ? imported : bundled)[sticker.pack] ??= []).add(
          sticker,
        );
      }
    }
    final sets = {...imported, ...bundled};
    final last = ref.watch(lastStickerPackProvider).value;
    final pack =
        _pack ??
        (last != null && (last.isEmpty || sets.containsKey(last))
            ? last
            : mine.isEmpty && sets.isNotEmpty
            ? sets.keys.first
            : '');
    final shown = pack.isEmpty ? mine : sets[pack] ?? const <ChatSticker>[];
    return Column(
      children: [
        Expanded(
          child: ChatStickerGrid(
            key: ValueKey(pack),
            stickers: shown,
            editable: pack.isEmpty,
            onPick: _pick,
          ),
        ),
        Divider(height: 1, thickness: 1, color: context.colors.border),
        ChatStickerPackBar(
          packs: [
            (pack: '', title: null, cover: null, removable: false),
            for (final MapEntry(:key, :value) in imported.entries)
              (
                pack: key,
                title: value.first.packTitle,
                cover: value.first,
                removable: true,
              ),
            for (final MapEntry(:key, :value) in bundled.entries)
              (pack: key, title: null, cover: value.first, removable: false),
          ],
          selected: pack,
          onSelect: _select,
          importing: [
            for (final job in ref.watch(stickerImportsProvider))
              if (!job.finished)
                (title: job.title, done: job.done, total: job.total),
          ],
          onAdd: _add,
          onImport: _import,
          onRemove: _remove,
        ),
      ],
    );
  }
}
