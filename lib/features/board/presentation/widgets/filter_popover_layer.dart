import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import 'chrome_bar.dart';
import 'filter_popover.dart';

/// The open advanced-filter popover over the board: a click outside it or Esc
/// closes it.
class FilterPopoverLayer extends ConsumerStatefulWidget {
  const FilterPopoverLayer({super.key});

  @override
  ConsumerState<FilterPopoverLayer> createState() => _FilterPopoverLayerState();
}

class _FilterPopoverLayerState extends ConsumerState<FilterPopoverLayer> {
  final _focus = FocusNode(debugLabel: 'filterPopover');

  @override
  void initState() {
    super.initState();
    // Opened from the toolbar, so focus is still on the Filters button (or the
    // search box): take it, or Esc would never reach this layer.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _close() => ref.read(advFilterOpenProvider.notifier).state = false;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _close},
      child: Focus(
        focusNode: _focus,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _close,
              ),
            ),
            Positioned(
              top: context.spacing.sm,
              left: context.spacing.xl2,
              child: const FilterPopover(),
            ),
          ],
        ),
      ),
    );
  }
}
