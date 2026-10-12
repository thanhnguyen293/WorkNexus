import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../l10n/app_localizations.dart';
import 'chat_sticker_set_buttons.dart';

export 'chat_sticker_set_buttons.dart'
    show ChatStickerImporting, ChatStickerPackCover;

/// The row under the sticker grid: one button per set (the user's own
/// first, then any set still being imported, with its progress), then
/// importing a Telegram set and "+" to add stickers of the user's own.
///
/// When the sets do not fit, arrows at either end scroll them a page at a
/// time; the selected set is scrolled into view when the bar opens.
class ChatStickerPackBar extends StatefulWidget {
  const ChatStickerPackBar({
    super.key,
    required this.packs,
    required this.selected,
    required this.onSelect,
    required this.onAdd,
    required this.onImport,
    required this.onRemove,
    this.importing = const [],
  });

  final List<ChatStickerPackCover> packs;
  final List<ChatStickerImporting> importing;
  final String selected;
  final ValueChanged<String> onSelect;
  final VoidCallback onAdd;
  final VoidCallback onImport;

  /// Removes an imported set (after asking).
  final ValueChanged<ChatStickerPackCover> onRemove;

  @override
  State<ChatStickerPackBar> createState() => _ChatStickerPackBarState();
}

class _ChatStickerPackBarState extends State<ChatStickerPackBar> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    // Opening on a set far along the bar: bring its button into view.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _reveal(animate: false),
    );
  }

  @override
  void didUpdateWidget(ChatStickerPackBar old) {
    super.didUpdateWidget(old);
    // The set opened on can arrive after the first frame (it is read from
    // disk); follow it.
    if (old.selected != widget.selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
    }
  }

  /// Centres the selected set's button. Worked out from its position, as the
  /// list only builds the buttons on screen: a far one has no widget yet.
  void _reveal({bool animate = true}) {
    if (!mounted || !_scroll.hasClients) return;
    final index = widget.packs.indexWhere((p) => p.pack == widget.selected);
    if (index < 0) return;
    // Sets being imported sit after the first button, shifting the rest.
    final slot = index == 0 ? 0 : index + widget.importing.length;
    final s = context.spacing;
    final width = s.xl6 + s.xs;
    final position = _scroll.position;
    final target =
        (s.md + slot * width - (position.viewportDimension - width) / 2).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );
    if (animate) {
      _scroll.animateTo(
        target,
        duration: AppMotion.base,
        curve: AppMotion.enter,
      );
    } else {
      _scroll.jumpTo(target);
    }
    _onScroll();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// The arrows follow what can still be scrolled to.
  void _onScroll() {
    if (mounted) setState(() {});
  }

  void _page(int direction) {
    final position = _scroll.position;
    final target =
        (position.pixels + direction * position.viewportDimension * 0.8).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );
    _scroll.animateTo(target, duration: AppMotion.base, curve: AppMotion.enter);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final l = AppL10n.of(context);
    final position = _scroll.hasClients ? _scroll.position : null;
    final overflows =
        position != null &&
        position.hasContentDimensions &&
        position.maxScrollExtent > 0;
    final buttons = [
      for (final (i, p) in widget.packs.indexed) ...[
        ChatStickerSetButton(
          pack: p,
          selected: p.pack == widget.selected,
          onTap: () => widget.onSelect(p.pack),
          onRemove: widget.onRemove,
        ),
        // Sets being imported sit right after the user's own.
        if (i == 0)
          for (final job in widget.importing)
            ChatStickerImportingMark(job: job),
      ],
    ];
    return SizedBox(
      height: s.xl6 + s.md * 2,
      child: Row(
        children: [
          if (overflows)
            AppIconButton(
              icon: LucideIcons.chevronLeft300,
              tooltip: l.chatStickerSetsBack,
              onPressed: position.extentBefore > 0 ? () => _page(-1) : null,
            ),
          Expanded(
            // Keyed so the arrow appearing before it does not rebuild the
            // list (and lose where it was scrolled to).
            key: const ValueKey('sets'),
            child: NotificationListener<ScrollMetricsNotification>(
              // A set added or removed changes whether the arrows are needed.
              onNotification: (_) {
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _onScroll(),
                );
                return false;
              },
              child: ListView(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.all(s.md),
                children: buttons,
              ),
            ),
          ),
          if (overflows)
            AppIconButton(
              icon: LucideIcons.chevronRight300,
              tooltip: l.chatStickerSetsForward,
              onPressed: position.extentAfter > 0 ? () => _page(1) : null,
            ),
          VerticalDivider(width: 1, color: context.colors.border),
          AppIconButton(
            icon: LucideIcons.packagePlus300,
            tooltip: l.stickerImportTitle,
            onPressed: widget.onImport,
          ),
          AppIconButton(
            icon: LucideIcons.plus300,
            tooltip: l.chatAddSticker,
            onPressed: widget.onAdd,
          ),
          SizedBox(width: s.xs),
        ],
      ),
    );
  }
}
