import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import 'chrome_bar.dart';
import 'filter_popover.dart';

/// Anchors the advanced-filter popover to the Filters button [child]. The
/// popover opens in the app's overlay, below the button and above everything
/// else (sidebar included), while [advFilterOpenProvider] is set; a click
/// anywhere outside it — the button aside, which toggles it — or Esc closes it.
class FilterPopoverAnchor extends ConsumerStatefulWidget {
  const FilterPopoverAnchor({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<FilterPopoverAnchor> createState() =>
      _FilterPopoverAnchorState();
}

class _FilterPopoverAnchorState extends ConsumerState<FilterPopoverAnchor> {
  final _portal = OverlayPortalController();
  final _link = LayerLink();
  final _focus = FocusNode(debugLabel: 'filterPopover');

  @override
  void initState() {
    super.initState();
    // Opened before this button mounted (a board switch rebuilt the toolbar).
    if (ref.read(advFilterOpenProvider)) _portal.show();
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _close() => ref.read(advFilterOpenProvider.notifier).state = false;

  @override
  Widget build(BuildContext context) {
    ref.listen(advFilterOpenProvider, (_, open) {
      if (open) {
        _portal.show();
        // Opened from the toolbar, focus is still on the Filters button: take
        // it, or Esc would never reach the popover.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _focus.requestFocus();
        });
      } else {
        _portal.hide();
      }
    });
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: (context) => CompositedTransformFollower(
          link: _link,
          targetAnchor: Alignment.bottomLeft,
          offset: Offset(0, context.spacing.sm),
          child: Align(
            alignment: AlignmentDirectional.topStart,
            child: TapRegion(
              groupId: kFilterPopoverTapGroup,
              onTapOutside: (_) => _close(),
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.escape): _close,
                },
                child: Focus(focusNode: _focus, child: const FilterPopover()),
              ),
            ),
          ),
        ),
        child: TapRegion(groupId: kFilterPopoverTapGroup, child: widget.child),
      ),
    );
  }
}
