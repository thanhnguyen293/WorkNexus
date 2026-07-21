import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

part 'detail_sidebar_section_overlay.dart';

typedef MetadataEditorBuilder =
    Widget Function(BuildContext context, VoidCallback close);

class DetailSidebarSection extends StatefulWidget {
  const DetailSidebarSection({
    super.key,
    required this.title,
    required this.child,
    this.action,
    this.trailingIcon,
    this.actionTooltip,
    this.editorTitle,
    this.editorBuilder,
  });

  final String title;
  final Widget child;
  final String? action;
  final IconData? trailingIcon;
  final String? actionTooltip;
  final String? editorTitle;
  final MetadataEditorBuilder? editorBuilder;

  @override
  State<DetailSidebarSection> createState() => _DetailSidebarSectionState();
}

class _DetailSidebarSectionState extends State<DetailSidebarSection> {
  final _link = LayerLink();
  final _portal = OverlayPortalController();
  double _popoverWidth = 0;
  bool _showAbove = false;

  void _toggleEditor() {
    if (_portal.isShowing) {
      _closeEditor();
      return;
    }
    final box = context.findRenderObject() as RenderBox?;
    final media = MediaQuery.of(context);
    final spacing = context.spacing;
    final targetSize = box?.size ?? Size.zero;
    final targetTop = box?.localToGlobal(Offset.zero).dy ?? 0;
    final horizontalMargin = spacing.xl3 * 2;
    final availableWidth = media.size.width - horizontalMargin;
    final preferredWidth = targetSize.width.clamp(
      spacing.xl6 * 8,
      spacing.xl6 * 10,
    );
    final availableBelow =
        media.size.height -
        media.padding.bottom -
        targetTop -
        targetSize.height;
    final preferredHeight = spacing.xl6 * 10;
    _popoverWidth = math.min(preferredWidth, availableWidth);
    _showAbove = availableBelow < preferredHeight && targetTop > availableBelow;
    _portal.show();
    setState(() {});
  }

  void _closeEditor() {
    _portal.hide();
    if (mounted) setState(() {});
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (context) => _MetadataOverlay(
        link: _link,
        width: _popoverWidth,
        showAbove: _showAbove,
        title: widget.editorTitle ?? widget.title,
        onClose: _closeEditor,
        child: widget.editorBuilder!(context, _closeEditor),
      ),
      child: CompositedTransformTarget(
        link: _link,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: context.spacing.lg),
          decoration: BoxDecoration(border: Border(top: context.hairlineSide)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(
                title: widget.title,
                action: widget.action,
                trailingIcon: widget.trailingIcon,
                actionTooltip: widget.actionTooltip,
                isOpen: _portal.isShowing,
                onAction: widget.editorBuilder == null ? null : _toggleEditor,
              ),
              SizedBox(height: context.spacing.sm),
              widget.child,
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.action,
    required this.trailingIcon,
    required this.actionTooltip,
    required this.isOpen,
    required this.onAction,
  });

  final String title;
  final String? action;
  final IconData? trailingIcon;
  final String? actionTooltip;
  final bool isOpen;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final actionColor = isOpen ? c.accent : c.textSecondary;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: context.typography.secondaryStrong.copyWith(
              color: c.textPrimary,
            ),
          ),
        ),
        if (action != null)
          Tooltip(
            message: actionTooltip ?? action!,
            child: InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(context.radii.sm),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.spacing.xs,
                  vertical: context.spacing.xs,
                ),
                child: Text(
                  action!,
                  style: context.typography.meta.copyWith(color: actionColor),
                ),
              ),
            ),
          ),
        if (trailingIcon != null)
          Tooltip(
            message: actionTooltip ?? title,
            child: InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(context.radii.sm),
              child: Padding(
                padding: EdgeInsets.all(context.spacing.xs),
                child: Icon(
                  trailingIcon,
                  size: context.spacing.xl3,
                  color: actionColor,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
