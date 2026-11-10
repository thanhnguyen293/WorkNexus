import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/app_search_field.dart';
import '../../../../l10n/app_localizations.dart';
import 'zentao_doc_reader_controller.dart';

/// Find in the open document: the query (marked on the page once typing
/// pauses), "3 of 12", previous / next. Enter goes to the next result,
/// Shift+Enter to the previous, Escape closes.
class ZenTaoDocFindBar extends StatefulWidget {
  const ZenTaoDocFindBar({
    super.key,
    required this.reader,
    required this.query,
    required this.onQuery,
    required this.onClose,
  });

  final ZenTaoDocReader reader;
  final String query;

  /// The query to mark, once typing has paused.
  final ValueChanged<String> onQuery;
  final VoidCallback onClose;

  @override
  State<ZenTaoDocFindBar> createState() => _ZenTaoDocFindBarState();
}

class _ZenTaoDocFindBarState extends State<ZenTaoDocFindBar> {
  late final _text = TextEditingController(text: widget.query);
  late final _focus = FocusNode(onKeyEvent: _onKey);
  Timer? _debounce;

  /// Re-marking a long page rebuilds it: wait for a pause in typing.
  static const _pause = Duration(milliseconds: 250);

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _changed(String value) {
    _debounce?.cancel();
    _debounce = Timer(_pause, () => widget.onQuery(value));
  }

  /// Enter steps through results (the query is marked at once if a pause
  /// is still pending); Escape closes.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onClose();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (_debounce?.isActive ?? false) {
        _debounce!.cancel();
        widget.onQuery(_text.text);
      } else if (HardwareKeyboard.instance.isShiftPressed) {
        widget.reader.previous();
      } else {
        widget.reader.next();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final c = context.colors;
    final s = context.spacing;
    final reader = widget.reader;
    // A floating card beside the reader's tools, not a band across the page.
    return Container(
      width: context.sizes.dialogSm,
      padding: EdgeInsets.all(s.xxs),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(context.radii.md),
        border: Border.all(color: c.border, width: context.borders.hairline),
      ),
      child: Row(
        children: [
          Expanded(
            child: AppSearchField(
              controller: _text,
              focusNode: _focus,
              autofocus: true,
              hint: l.docsFindHint,
              onChanged: _changed,
            ),
          ),
          SizedBox(width: s.sm),
          ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: context.sizes.controlLg * 1.5,
            ),
            child: ListenableBuilder(
              listenable: Listenable.merge([reader.current, reader.total]),
              builder: (context, _) => Text(
                widget.query.trim().isEmpty
                    ? ''
                    : reader.matchCount == 0
                    ? l.docsFindNone
                    : l.docsFindCount(
                        reader.current.value + 1,
                        reader.matchCount,
                      ),
                textAlign: TextAlign.center,
                style: context.typography.bodySm.copyWith(
                  color: c.textSecondary,
                ),
              ),
            ),
          ),
          AppIconButton(
            icon: LucideIcons.chevronUp300,
            tooltip: l.docsFindPrevious,
            onPressed: reader.previous,
          ),
          AppIconButton(
            icon: LucideIcons.chevronDown300,
            tooltip: l.docsFindNext,
            onPressed: reader.next,
          ),
          AppIconButton(
            icon: LucideIcons.x300,
            tooltip: l.docsFindClose,
            onPressed: widget.onClose,
          ),
        ],
      ),
    );
  }
}
