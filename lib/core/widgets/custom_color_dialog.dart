import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import 'app_button.dart';
import 'app_dialog_frame.dart';
import 'connection_text_field.dart';
import 'hsv_color_fields.dart';

/// Opens the free colour picker on [initial]; resolves to the picked opaque
/// colour as `0xAARRGGBB`, or null when dismissed.
Future<int?> showCustomColorDialog(
  BuildContext context, {
  required Color initial,
}) => showDialog<int>(
  context: context,
  builder: (_) => _CustomColorDialog(initial: initial),
);

/// `#rrggbb` (or `rrggbb`, any case) → an opaque colour; null if malformed.
Color? parseHexColor(String text) {
  final hex = text.trim().replaceFirst('#', '');
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex)) return null;
  return Color(0xFF000000 | int.parse(hex, radix: 16));
}

/// [color] as `#RRGGBB`.
String hexOf(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

class _CustomColorDialog extends StatefulWidget {
  const _CustomColorDialog({required this.initial});

  final Color initial;

  @override
  State<_CustomColorDialog> createState() => _CustomColorDialogState();
}

class _CustomColorDialogState extends State<_CustomColorDialog> {
  late var _color = HSVColor.fromColor(widget.initial);
  late final _hex = TextEditingController(text: hexOf(widget.initial));
  var _hexInvalid = false;

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  /// From the area or the hue bar: the hex field follows.
  void _pick(HSVColor next) => setState(() {
    _color = next;
    _hex.text = hexOf(next.toColor());
    _hexInvalid = false;
  });

  /// From the hex field: the area and bar follow once it parses.
  void _typed(String text) {
    final parsed = parseHexColor(text);
    setState(() {
      _hexInvalid = parsed == null;
      // Keep the hue when the typed colour is grey (it has none of its own).
      if (parsed != null) {
        final next = HSVColor.fromColor(parsed);
        _color = next.saturation == 0 ? next.withHue(_color.hue) : next;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final s = context.spacing;
    return AppDialogFrame(
      title: l.colorCustom,
      maxWidth: s.xl6 * 9,
      actions: [
        const Spacer(),
        AppButton.textNeutral(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        AppButton.filled(
          isDisabled: _hexInvalid,
          onPressed: () =>
              Navigator.pop(context, _color.toColor().toARGB32() | 0xFF000000),
          child: Text(l.save),
        ),
      ],
      child: Padding(
        padding: EdgeInsets.fromLTRB(s.xl3, 0, s.xl3, s.xl2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: s.xl,
          children: [
            HsvSaturationValueArea(color: _color, onChanged: _pick),
            HsvHueBar(color: _color, onChanged: _pick),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              spacing: s.md,
              children: [
                Expanded(
                  child: ConnectionTextField(
                    label: l.colorHex,
                    controller: _hex,
                    errorText: _hexInvalid ? l.colorHexInvalid : null,
                    onChanged: _typed,
                  ),
                ),
                _Preview(color: _color.toColor()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The colour as it will look, beside the hex field.
class _Preview extends StatelessWidget {
  const _Preview({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final size = context.spacing.xl6;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(context.radii.md),
        border: Border.all(color: context.colors.border),
      ),
    );
  }
}
