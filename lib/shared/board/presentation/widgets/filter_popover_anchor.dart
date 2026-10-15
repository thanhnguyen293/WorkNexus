import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/theme/app_spacing.dart';
import 'filter_facet_groups.dart';
import 'filter_popover.dart';

/// Whether the advanced-filter popover is open.
final advFilterOpenProvider = StateProvider<bool>((ref) => false);

/// The tap region shared by the Filters button and its popover: a click
/// anywhere else closes the popover, while the button keeps toggling it.
const kFilterPopoverTapGroup = #filterPopover;

/// Anchors the advanced-filter popover to the Filters button [child]. The
/// popover opens in the app's overlay, below the button and above everything
/// else (sidebar included), while [advFilterOpenProvider] is set; a click
/// anywhere outside it — the button aside, which toggles it — or Esc closes it.
class FilterPopoverAnchor extends ConsumerStatefulWidget {
  const FilterPopoverAnchor({
    super.key,
    required this.child,
    this.statusOption,
  });

  final Widget child;

  /// How a facet status option is drawn (see [FacetFilterGroups.statusOption]).
  final FacetStatusOption? statusOption;

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
    if (ref.read(advFilterOpenProvider)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && TickerMode.valuesOf(context).enabled) {
          _portal.show();
        }
      });
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _close() => ref.read(advFilterOpenProvider.notifier).state = false;

  @override
  Widget build(BuildContext context) {
    final isActive = TickerMode.valuesOf(context).enabled;
    if (!isActive && _portal.isShowing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _portal.isShowing) {
          _portal.hide();
        }
      });
    }

    ref.listen(advFilterOpenProvider, (_, open) {
      if (open) {
        if (TickerMode.valuesOf(context).enabled) {
          _portal.show();
          // Opened from the toolbar, focus is still on the Filters button: take
          // it, or Esc would never reach the popover.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _focus.requestFocus();
          });
        }
      } else {
        if (_portal.isShowing) _portal.hide();
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
                child: Focus(
                  focusNode: _focus,
                  child: FilterPopover(statusOption: widget.statusOption),
                ),
              ),
            ),
          ),
        ),
        child: TapRegion(groupId: kFilterPopoverTapGroup, child: widget.child),
      ),
    );
  }
}
