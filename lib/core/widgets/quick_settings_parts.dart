import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_borders.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// A group of related Quick Settings: an uppercase heading over one card,
/// its rows split by hairlines. Every tab of the panel is built from these,
/// so app and feature settings read as one system.
class QuickSettingsSection extends StatelessWidget {
  const QuickSettingsSection({
    required this.title,
    required this.children,
    super.key,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final radius = BorderRadius.circular(context.radii.lg);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(left: s.xs, bottom: s.md),
          child: Text(
            title.toUpperCase(),
            style: context.typography.labelLoose.copyWith(
              color: c.textTertiary,
            ),
          ),
        ),
        Material(
          color: c.surface,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: context.hairlineSide,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) Divider(height: 1, thickness: 1, color: c.border),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The inset every row of a [QuickSettingsSection] card shares.
EdgeInsets _rowPadding(BuildContext context) => EdgeInsets.symmetric(
  horizontal: context.spacing.xl,
  vertical: context.spacing.lg,
);

/// A row's title, with an optional hint underneath.
class _RowLabel extends StatelessWidget {
  const _RowLabel({required this.label, this.hint, this.enabled = true});

  final String label;
  final String? hint;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hint = this.hint;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.typography.bodySmStrong.copyWith(
            color: enabled ? c.textPrimary : c.textTertiary,
          ),
        ),
        if (hint != null) ...[
          SizedBox(height: context.spacing.xxs),
          Text(
            hint,
            style: context.typography.caption.copyWith(
              color: enabled ? c.textSecondary : c.textTertiary,
            ),
          ),
        ],
      ],
    );
  }
}

/// One setting row: label left, [control] right at a fixed width, so every
/// control lines up and none gets scaled down. [stacked] puts the control
/// under the label at full width instead — for grids (swatches, previews).
class QuickSettingsField extends StatelessWidget {
  const QuickSettingsField({
    required this.label,
    required this.control,
    this.trailing,
    this.stacked = false,
    super.key,
  });

  final String label;
  final Widget control;

  /// A readout shown right of the label on a [stacked] row.
  final Widget? trailing;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    if (!stacked) {
      return Padding(
        padding: _rowPadding(context),
        child: Row(
          children: [
            Expanded(child: _RowLabel(label: label)),
            SizedBox(width: s.md),
            SizedBox(width: s.xl6 * 5.25, child: control),
          ],
        ),
      );
    }
    return Padding(
      padding: _rowPadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _RowLabel(label: label)),
              ?trailing,
            ],
          ),
          SizedBox(height: s.md),
          control,
        ],
      ),
    );
  }
}

/// A setting that is simply on or off: label (and [hint]) left, switch
/// right; the whole row toggles. A null [onChanged] greys it out.
class QuickSettingsSwitchField extends StatelessWidget {
  const QuickSettingsSwitchField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
    super.key,
  });

  final String label;
  final String? hint;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    return InkWell(
      mouseCursor: onChanged == null
          ? SystemMouseCursors.basic
          : WidgetStateMouseCursor.clickable,
      onTap: onChanged == null ? null : () => onChanged(!value),
      child: Padding(
        padding: _rowPadding(context),
        child: Row(
          children: [
            Expanded(
              child: _RowLabel(
                label: label,
                hint: hint,
                enabled: onChanged != null,
              ),
            ),
            SizedBox(width: context.spacing.md),
            Transform.scale(
              // The Material switch is sized for touch; the panel is dense.
              scale: 0.8,
              alignment: Alignment.centerRight,
              child: Switch(value: value, onChanged: onChanged),
            ),
          ],
        ),
      ),
    );
  }
}

/// A row that opens somewhere else (a dialog, a page): icon, label, caret.
class QuickSettingsLinkField extends StatelessWidget {
  const QuickSettingsLinkField({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    return InkWell(
      mouseCursor: WidgetStateMouseCursor.clickable,
      onTap: onTap,
      child: Padding(
        padding: _rowPadding(context),
        child: Row(
          children: [
            Icon(icon, size: s.xl3, color: c.textSecondary),
            SizedBox(width: s.md),
            Expanded(child: _RowLabel(label: label)),
            Icon(
              LucideIcons.chevronRight300,
              size: s.xl2,
              color: c.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
