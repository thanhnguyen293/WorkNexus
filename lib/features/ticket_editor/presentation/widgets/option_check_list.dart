import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/domain/entities/zentao_ticket_form.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hover_surface.dart';

/// The search field at the top of an option picker.
class OptionSearchBox extends StatelessWidget {
  const OptionSearchBox({
    super.key,
    required this.hint,
    required this.onChanged,
  });

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(context.radii.md),
      borderSide: BorderSide(color: color),
    );
    return TextField(
      autofocus: true,
      onChanged: onChanged,
      style: context.typography.body.copyWith(color: c.textPrimary),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: c.surfaceSubtle,
        hintText: hint,
        hintStyle: context.typography.body.copyWith(color: c.textTertiary),
        prefixIcon: Icon(
          PhosphorIconsLight.magnifyingGlass,
          size: s.xl3,
          color: c.textTertiary,
        ),
        prefixIconConstraints: BoxConstraints(minWidth: s.xl6),
        contentPadding: EdgeInsets.symmetric(vertical: s.lg),
        border: border(c.border),
        enabledBorder: border(c.border),
        focusedBorder: border(c.accent),
      ),
    );
  }
}

/// The options as checkable rows; [emptyLabel] when none match.
class OptionCheckList extends StatelessWidget {
  const OptionCheckList({
    super.key,
    required this.options,
    required this.picked,
    required this.emptyLabel,
    required this.onToggle,
  });

  final List<FormOption> options;
  final Set<String> picked;
  final String emptyLabel;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    if (options.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(s.xl4),
        child: Text(
          emptyLabel,
          textAlign: TextAlign.center,
          style: context.typography.bodySm.copyWith(
            color: context.colors.textTertiary,
          ),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.symmetric(horizontal: s.lg, vertical: s.xs),
      itemCount: options.length,
      itemBuilder: (context, i) {
        final o = options[i];
        return _CheckRow(
          label: o.label,
          checked: picked.contains(o.value),
          onTap: () => onToggle(o.value),
        );
      },
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.label,
    required this.checked,
    required this.onTap,
  });

  final String label;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    return HoverSurface(
      onTap: onTap,
      padding: EdgeInsets.symmetric(horizontal: s.md, vertical: s.md),
      color: checked ? c.selectionFill : null,
      borderRadius: BorderRadius.circular(context.radii.md),
      child: Row(
        children: [
          Icon(
            checked ? PhosphorIconsFill.checkSquare : PhosphorIconsLight.square,
            size: s.xl4,
            color: checked ? c.accent : c.textTertiary,
          ),
          SizedBox(width: s.lg),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: context.typography.body.copyWith(
                color: c.textPrimary,
                fontWeight: checked ? FontWeight.w600 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
