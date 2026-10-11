import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_icon_button.dart';
import 'app_input_decoration.dart';

/// The app's search box: a magnifier, the [hint], and a clear button once
/// there is text. Esc clears the text; on an empty box it passes through to
/// the surrounding panel / popover (which typically closes). The caller owns the [controller] (and so the query); [onChanged]
/// also fires with `''` when the box is cleared.
///
/// It is exactly [height] tall (default: the toolbar control height), so it
/// lines up with the buttons beside it whether or not the clear button shows.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    required this.controller,
    required this.hint,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.autofocus = false,
    this.fillColor,
    this.height,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final bool autofocus;
  final Color? fillColor;
  final double? height;

  void _clear() {
    controller.clear();
    onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final boxHeight = height ?? context.sizes.controlMd;
    return SizedBox(
      height: boxHeight,
      // Esc clears the query; on an empty box it passes through, so the
      // panel or popover around the field can close on it.
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent ||
              event.logicalKey != LogicalKeyboardKey.escape ||
              controller.text.isEmpty) {
            return KeyEventResult.ignored;
          }
          _clear();
          return KeyEventResult.handled;
        },
        child: ValueListenableBuilder(
          valueListenable: controller,
          builder: (context, value, _) => TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: autofocus,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            textAlignVertical: TextAlignVertical.center,
            textInputAction: TextInputAction.search,
            style: context.typography.body.copyWith(color: c.textPrimary),
            decoration:
                appInputDecoration(
                  context,
                  hint: hint,
                  prefixIcon: LucideIcons.search300,
                  fillColor: fillColor,
                  contentPadding: EdgeInsetsDirectional.only(
                    end: context.spacing.md,
                  ),
                  suffix: value.text.isEmpty
                      ? null
                      : AppIconButton(
                          icon: LucideIcons.x300,
                          tooltip: AppL10n.of(context).clearSearch,
                          size: AppIconButtonSize.small,
                          onPressed: _clear,
                        ),
                ).copyWith(
                  // A long hint ellipsizes on one line rather than wrapping
                  // out of the fixed-height box.
                  hintMaxLines: 1,
                  // Pins the field to the box, so it neither grows with the
                  // clear button nor shrinks when it goes away.
                  constraints: BoxConstraints.tightFor(height: boxHeight),
                ),
          ),
        ),
      ),
    );
  }
}
