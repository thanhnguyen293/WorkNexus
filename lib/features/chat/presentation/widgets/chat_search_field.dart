import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/chat_providers.dart';

/// The chat search box. Its text lives in [chatSearchProvider] (the list
/// filters by it), so a box rebuilt after switching views starts from that
/// text rather than empty over a still-filtered list.
class ChatSearchField extends ConsumerStatefulWidget {
  const ChatSearchField({super.key, required this.hint});

  final String hint;

  @override
  ConsumerState<ChatSearchField> createState() => _ChatSearchFieldState();
}

class _ChatSearchFieldState extends ConsumerState<ChatSearchField> {
  late final _text = TextEditingController(text: ref.read(chatSearchProvider));

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final shape = OutlineInputBorder(
      borderRadius: BorderRadius.circular(context.radii.md),
      borderSide: BorderSide.none,
    );
    return SizedBox(
      height: s.xl6 - s.xs,
      child: ValueListenableBuilder(
        valueListenable: _text,
        builder: (context, value, _) => TextField(
          controller: _text,
          onChanged: _search,
          // Fills the box: otherwise it is only as tall as its content, and
          // shrinks once the clear button goes away with the text.
          expands: true,
          maxLines: null,
          textAlignVertical: TextAlignVertical.center,
          style: context.typography.body.copyWith(color: c.textPrimary),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: c.surfaceSubtle,
            hintText: widget.hint,
            hintStyle: context.typography.body.copyWith(color: c.textTertiary),
            prefixIcon: Icon(
              PhosphorIconsLight.magnifyingGlass,
              size: s.xl3,
              color: c.textTertiary,
            ),
            prefixIconConstraints: BoxConstraints(minWidth: s.xl6 - s.xs),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).clearButtonTooltip,
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      _text.clear();
                      _search('');
                    },
                    icon: Icon(
                      PhosphorIconsLight.x,
                      size: s.xl2,
                      color: c.textTertiary,
                    ),
                  ),
            contentPadding: EdgeInsets.zero,
            border: shape,
            enabledBorder: shape,
            focusedBorder: shape.copyWith(
              borderSide: BorderSide(color: c.accent),
            ),
          ),
        ),
      ),
    );
  }

  void _search(String text) =>
      ref.read(chatSearchProvider.notifier).state = text;
}
