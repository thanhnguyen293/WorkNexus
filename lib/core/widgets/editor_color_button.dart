import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../util/editor_text_colors.dart';
import 'hover_surface.dart';

/// The rich-text toolbar's text-colour (or, with [isBackground], highlight)
/// button: a swatch grid that drops down under it, in place of
/// flutter_quill's Material colour dialog.
class EditorColorButton extends StatefulWidget {
  const EditorColorButton({
    super.key,
    required this.controller,
    required this.isBackground,
    required this.iconSize,
  });

  final QuillController controller;
  final bool isBackground;
  final double iconSize;

  @override
  State<EditorColorButton> createState() => _EditorColorButtonState();
}

class _EditorColorButtonState extends State<EditorColorButton> {
  final _menu = MenuController();

  String get _key =>
      widget.isBackground ? Attribute.background.key : Attribute.color.key;

  /// The selection's colour as `#rrggbb`, or null when it has none.
  String? get _current {
    final value = widget.controller.getSelectionStyle().attributes[_key]?.value;
    if (value is! String || !value.startsWith('#')) return null;
    final hex = value.toLowerCase();
    // Quill writes `#aarrggbb`; the palette is opaque `#rrggbb`.
    return hex.length == 9 ? '#${hex.substring(3)}' : hex;
  }

  void _apply(String? hex) {
    _menu.close();
    widget.controller.formatSelection(
      widget.isBackground ? BackgroundAttribute(hex) : ColorAttribute(hex),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final current = _current;
    return MenuAnchor(
      controller: _menu,
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(c.card),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(context.radii.lg),
            side: BorderSide(color: c.border),
          ),
        ),
      ),
      menuChildren: [_Palette(current: current, onPick: _apply)],
      builder: (context, menu, _) => IconButton(
        tooltip: widget.isBackground
            ? l.editorHighlightColor
            : l.editorTextColor,
        iconSize: widget.iconSize,
        color: c.textSecondary,
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(context.radii.sm),
            ),
          ),
        ),
        onPressed: () => menu.isOpen ? menu.close() : menu.open(),
        icon: _ColorGlyph(
          icon: widget.isBackground
              ? PhosphorIconsLight.highlighterCircle
              : PhosphorIconsLight.textAa,
          size: widget.iconSize,
          color: current == null ? null : _parse(current),
        ),
      ),
    );
  }
}

/// The button's glyph over a bar in the selection's colour.
class _ColorGlyph extends StatelessWidget {
  const _ColorGlyph({required this.icon, required this.size, this.color});

  final IconData icon;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: size * 0.85),
        SizedBox(height: context.spacing.xxs),
        Container(
          width: size,
          height: context.spacing.xs,
          decoration: BoxDecoration(
            color: color ?? c.border,
            borderRadius: BorderRadius.circular(context.radii.sm),
          ),
        ),
      ],
    );
  }
}

/// The drop-down: "default" (no colour) over the swatch grid.
class _Palette extends StatelessWidget {
  const _Palette({required this.current, required this.onPick});

  final String? current;
  final ValueChanged<String?> onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final swatch = s.xl5;
    return Padding(
      padding: EdgeInsets.all(s.lg),
      child: SizedBox(
        width: swatch * editorTextColorColumns + s.sm * 5,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            HoverSurface(
              onTap: () => onPick(null),
              padding: EdgeInsets.symmetric(horizontal: s.md, vertical: s.sm),
              color: current == null ? c.selectionFill : null,
              borderRadius: BorderRadius.circular(context.radii.md),
              child: Row(
                children: [
                  Icon(
                    PhosphorIconsLight.prohibit,
                    size: s.xl3,
                    color: c.textTertiary,
                  ),
                  SizedBox(width: s.md),
                  Text(
                    AppL10n.of(context).colorDefault,
                    style: context.typography.bodySm.copyWith(
                      color: c.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: s.md),
            Wrap(
              spacing: s.sm,
              runSpacing: s.sm,
              children: [
                for (final hex in editorTextColors)
                  HoverSurface(
                    key: ValueKey(hex),
                    onTap: () => onPick(hex),
                    width: swatch,
                    height: swatch,
                    color: _parse(hex),
                    borderRadius: BorderRadius.circular(context.radii.sm),
                    // The ring answers hover: a tint would shift the colour.
                    tintOnHover: false,
                    border: Border.all(
                      color: hex == current ? c.textPrimary : c.border,
                      width: hex == current ? 2 : 1,
                    ),
                    hoverBorder: Border.all(
                      color: hex == current ? c.textPrimary : c.borderStrong,
                      width: 2,
                    ),
                    alignment: Alignment.center,
                    child: hex == current
                        ? Icon(
                            PhosphorIconsBold.check,
                            size: s.xl2,
                            color: _onSwatch(hex),
                          )
                        : null,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Color _parse(String hex) =>
    Color(int.parse('ff${hex.substring(1)}', radix: 16));

/// A check that reads on the swatch it sits on.
Color _onSwatch(String hex) => _parse(hex).computeLuminance() > 0.5
    ? _parse('#000000')
    : _parse('#ffffff');
