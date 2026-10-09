import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/domain/entities/workspace.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import 'workspace_picker_popover.dart';

/// The workspace dropdown shared by the connection dialogs: lists existing
/// workspaces plus a "New workspace…" entry ([newValue]).
///
/// Rendered as a themed popover (matching the app's other dropdowns) rather
/// than a native Material menu.
class WorkspacePicker extends StatefulWidget {
  const WorkspacePicker({
    super.key,
    required this.workspaces,
    required this.value,
    required this.newValue,
    required this.onChanged,
  });

  final List<Workspace> workspaces;
  final String? value;
  final String newValue;
  final ValueChanged<String?> onChanged;

  @override
  State<WorkspacePicker> createState() => _WorkspacePickerState();
}

class _WorkspacePickerState extends State<WorkspacePicker> {
  final _link = LayerLink();
  final _portal = OverlayPortalController();
  double _fieldWidth = 260;

  void _open() {
    final box = context.findRenderObject() as RenderBox?;
    _fieldWidth = box?.size.width ?? 260;
    _portal.show();
  }

  void _select(String? value) {
    widget.onChanged(value);
    _portal.hide();
  }

  String _labelOf(Workspace w) =>
      w.isPersonal ? AppL10n.of(context).personal : w.name;

  String? _selectedLabel() {
    final id = widget.value;
    if (id == null || id == widget.newValue) return null;
    for (final w in widget.workspaces) {
      if (w.id == id) return _labelOf(w);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.workspace,
          style: context.typography.captionStrong.copyWith(
            color: c.textSecondary,
          ),
        ),
        SizedBox(height: context.spacing.xs),
        OverlayPortal(
          controller: _portal,
          overlayChildBuilder: (_) => WorkspacePickerPopover(
            link: _link,
            fieldWidth: _fieldWidth,
            workspaces: widget.workspaces,
            selectedId: widget.value,
            labelOf: _labelOf,
            newLabel: l.newWorkspaceOption,
            onClose: _portal.hide,
            onSelect: _select,
            onSelectNew: () => _select(widget.newValue),
          ),
          child: CompositedTransformTarget(
            link: _link,
            child: _ClosedField(
              label: _selectedLabel(),
              hint: l.workspace,
              onTap: _open,
            ),
          ),
        ),
      ],
    );
  }
}

/// The tap target shown when the popover is closed.
class _ClosedField extends StatelessWidget {
  const _ClosedField({
    required this.label,
    required this.hint,
    required this.onTap,
  });

  final String? label;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final spacing = context.spacing;
    final hasValue = label != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(context.radii.md),
        child: Container(
          decoration: BoxDecoration(
            color: c.surfaceSubtle,
            borderRadius: BorderRadius.circular(context.radii.md),
            border: Border.all(color: c.border),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: spacing.lg,
            vertical: spacing.lg,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  hasValue ? label! : hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.body.copyWith(
                    color: hasValue ? c.textPrimary : c.textTertiary,
                  ),
                ),
              ),
              Icon(
                PhosphorIconsLight.caretDown,
                size: 20,
                color: c.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
