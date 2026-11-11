import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/navigation_providers.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_sizes.dart';
import 'detail_panel.dart';
import 'detail_providers.dart';

/// Hosts the animated right slide-over. Always present in the tree; shows/hides
/// based on [openTicketIdProvider].
///
/// Each place (the chat, an account's Bugs / Tasks / Docs…) keeps its own
/// slide-over: going elsewhere hides it at once (built, so its scroll and tab
/// stay) and coming back shows it at once, as it was left. The rail stays uncovered, so another place can be
/// picked with a detail open.
class DetailOverlay extends ConsumerStatefulWidget {
  const DetailOverlay({super.key});

  @override
  ConsumerState<DetailOverlay> createState() => _DetailOverlayState();
}

class _DetailOverlayState extends ConsumerState<DetailOverlay>
    with SingleTickerProviderStateMixin {
  // Made up front, not lazily: a build with nothing to show never touches it,
  // and creating it first in dispose looks up a deactivated ancestor.
  late final AnimationController _c;

  /// The ticket each place's slide-over shows; the one on screen is kept
  /// while it slides closed.
  Map<String, String> _shown = const {};
  final Map<String, FocusNode> _focus = {};

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: AppMotion.slow);
  }

  @override
  void dispose() {
    _c.dispose();
    for (final node in _focus.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _close() => ref.read(appNavProvider.notifier).closeTicket();

  void _back() => ref.read(appNavProvider.notifier).back();

  /// The platform's "go back": Cmd+[ on macOS, Alt+Left elsewhere (neither
  /// moves the caret in a text field there, so typing a comment is unaffected).
  static SingleActivator get _backShortcut =>
      defaultTargetPlatform == TargetPlatform.macOS
      ? const SingleActivator(LogicalKeyboardKey.bracketLeft, meta: true)
      : const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true);

  static Map<String, String> _tops(AppNavState nav) => {
    for (final e in nav.ticketHistories.entries) e.key: e.value.last,
  };

  void _show(Map<String, String> shown) {
    setState(() => _shown = shown);
    for (final place in _focus.keys.toList()) {
      if (!shown.containsKey(place)) _focus.remove(place)?.dispose();
    }
  }

  void _onNav(AppNavState? prev, AppNavState next) {
    final id = next.openTicketId;
    final prevId = prev?.openTicketId;
    final placeChanged = prev != null && prev.detailPlace != next.detailPlace;
    final closed = !placeChanged && id == null && prevId != null;
    _show({
      ..._tops(next),
      // Still on screen while it slides closed.
      if (closed) next.detailPlace: prevId,
    });
    if (placeChanged) {
      _c.value = id == null ? 0 : 1;
    } else if (closed) {
      _c.reverse().then((_) {
        if (mounted) _show(_tops(ref.read(appNavProvider)));
      });
    } else if (id != null && id != prevId) {
      ref.invalidate(detailTabProvider(id));
      // Every open refetches the ticket's detail: drop any result kept from a
      // previous open (e.g. reopened during the close animation, before the
      // autoDispose provider was disposed).
      ref.invalidate(ticketDetailSyncProvider(id));
      _c.forward();
    } else {
      return;
    }
    if (id == null) return;
    // Take focus so Esc closes the panel without a click into it first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus[next.detailPlace]?.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AppNavState>(appNavProvider, _onNav);
    if (_shown.isEmpty) return const SizedBox.shrink();
    final here = ref.watch(appNavProvider.select((s) => s.detailPlace));

    // Two-pane needs room for the content column plus the metadata sidebar, so
    // the slide-over opens wider than the single-column document layout.
    final layout = ref.watch(appSettingsProvider.select((s) => s.detailLayout));
    final railWidth = context.sizes.railWidth;
    final screenWidth = MediaQuery.of(context).size.width;
    final twoPane = layout == DetailLayout.twoPane;
    final width = (screenWidth * (twoPane ? 0.64 : 0.52))
        .clamp(twoPane ? 680.0 : 460.0, twoPane ? 1000.0 : 760.0)
        .clamp(0.0, (screenWidth - railWidth).clamp(0.0, screenWidth));
    final curve = CurvedAnimation(parent: _c, curve: AppMotion.enter);

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Stack(
        children: [
          Positioned(
            top: 0,
            bottom: 0,
            left: railWidth,
            right: 0,
            child: IgnorePointer(
              ignoring: _c.value < 0.05,
              child: GestureDetector(
                onTap: _close,
                child: ColoredBox(
                  color: context.colors.scrim.withValues(alpha: 0.5 * _c.value),
                ),
              ),
            ),
          ),
          for (final MapEntry(key: place, value: id) in _shown.entries)
            Positioned(
              key: ValueKey(place),
              top: 0,
              bottom: 0,
              right: 0,
              width: width,
              // Another place's, or set aside: out of the way of focus and
              // hit tests, its state kept.
              child: Offstage(
                offstage: place != here || _c.isDismissed,
                child: FractionalTranslation(
                  translation: Offset(place == here ? 1 - curve.value : 0, 0),
                  child: Listener(
                    onPointerDown: (event) {
                      if (event.buttons & kBackMouseButton != 0) _back();
                    },
                    child: CallbackShortcuts(
                      bindings: {
                        const SingleActivator(LogicalKeyboardKey.escape):
                            _close,
                        _backShortcut: _back,
                      },
                      child: Focus(
                        focusNode: _focus.putIfAbsent(
                          place,
                          () => FocusNode(debugLabel: 'detail-panel'),
                        ),
                        child: DetailPanel(ticketId: id, onClose: _close),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
