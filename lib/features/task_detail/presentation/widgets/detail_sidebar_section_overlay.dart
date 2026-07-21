part of 'detail_sidebar_section.dart';

class _MetadataOverlay extends StatelessWidget {
  const _MetadataOverlay({
    required this.link,
    required this.width,
    required this.showAbove,
    required this.title,
    required this.onClose,
    required this.child,
  });

  final LayerLink link;
  final double width;
  final bool showAbove;
  final String title;
  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final spacing = context.spacing;
    final popup = Material(
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(maxHeight: spacing.xl6 * 10),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(context.radii.lg),
          border: Border.all(color: c.border),
          boxShadow: [
            BoxShadow(
              color: c.mixT(c.scrim, 0.18),
              blurRadius: spacing.xl4,
              offset: Offset(0, spacing.md),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                spacing.xl,
                spacing.md,
                spacing.sm,
                spacing.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: context.typography.secondaryStrong.copyWith(
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                    iconSize: spacing.xl4,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: c.border),
            Flexible(child: child),
          ],
        ),
      ),
    );
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onClose,
          ),
        ),
        CompositedTransformFollower(
          link: link,
          targetAnchor: showAbove ? Alignment.topRight : Alignment.bottomRight,
          followerAnchor: showAbove
              ? Alignment.bottomRight
              : Alignment.topRight,
          offset: Offset(0, showAbove ? -spacing.xs : spacing.xs),
          child: SizedBox(width: width, child: popup),
        ),
      ],
    );
  }
}
