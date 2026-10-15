import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/navigation/navigation_providers.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_borders.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/tools/tool_registry_provider.dart';
import 'detail_providers.dart';
import 'widgets/detail_header.dart';
import 'widgets/detail_tab_bar.dart';
import 'widgets/detail_tab_body.dart';
import 'widgets/translation_footer.dart';

/// Hosts the animated right slide-over. Always present in the tree; shows/hides
/// based on [openTicketIdProvider].
class DetailOverlay extends ConsumerStatefulWidget {
  const DetailOverlay({super.key});

  @override
  ConsumerState<DetailOverlay> createState() => _DetailOverlayState();
}

class _DetailOverlayState extends ConsumerState<DetailOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppMotion.slow,
  );
  final _focus = FocusNode(debugLabel: 'detail-panel');
  String? _current;

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
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

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(openTicketIdProvider, (prev, next) {
      if (next != null) {
        setState(() => _current = next);
        ref.read(detailTabProvider.notifier).set(DetailTab.original);
        // Every open refetches the ticket's detail: drop any result kept from a
        // previous open (e.g. reopened during the close animation, before the
        // autoDispose provider was disposed).
        ref.invalidate(ticketDetailSyncProvider(next));
        _c.forward();
        // Take focus so Esc closes the panel without a click into it first.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _focus.requestFocus();
        });
      } else {
        _c.reverse().then((_) {
          if (mounted) setState(() => _current = null);
        });
      }
    });

    final id = _current;
    if (id == null && _c.isDismissed) return const SizedBox.shrink();

    // Two-pane needs room for the content column plus the metadata sidebar, so
    // the slide-over opens wider than the single-column document layout.
    final layout = ref.watch(appSettingsProvider.select((s) => s.detailLayout));
    final screenWidth = MediaQuery.of(context).size.width;
    final twoPane = layout == DetailLayout.twoPane;
    final width = (screenWidth * (twoPane ? 0.64 : 0.52))
        .clamp(twoPane ? 680.0 : 460.0, twoPane ? 1000.0 : 760.0)
        .clamp(0.0, screenWidth);
    final curve = CurvedAnimation(parent: _c, curve: AppMotion.enter);

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                ignoring: _c.value < 0.05,
                child: GestureDetector(
                  onTap: _close,
                  child: ColoredBox(
                    color: context.colors.scrim.withValues(
                      alpha: 0.5 * _c.value,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              width: width,
              child: FractionalTranslation(
                translation: Offset(1 - curve.value, 0),
                child: id == null
                    ? const SizedBox.shrink()
                    : Listener(
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
                            focusNode: _focus,
                            child: DetailPanel(ticketId: id, onClose: _close),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class DetailPanel extends ConsumerWidget {
  const DetailPanel({super.key, required this.ticketId, this.onClose});
  final String ticketId;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final ticket = ref.watch(ticketByIdProvider(ticketId));
    if (ticket == null) return const SizedBox.shrink();
    final lookups = ref.watch(lookupsProvider);
    final account = lookups.accounts[ticket.accountId];
    final ws = account == null ? null : lookups.workspaces[account.workspaceId];
    final wsColor = ws == null ? c.workspaceFallback : Color(ws.colorValue);
    final tab = ref.watch(detailTabProvider);
    final layout = ref.watch(appSettingsProvider.select((s) => s.detailLayout));
    // Pull fresh detail + comments from the provider when the panel opens.
    final detailLoading = ref
        .watch(ticketDetailSyncProvider(ticketId))
        .isLoading;
    final module = ref.watch(toolRegistryProvider)[ticket.providerType];
    final customDetail = module?.buildDetail(context, ticket, onClose: onClose);

    final Widget body;
    if (customDetail != null) {
      body = customDetail;
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DetailHeader(
            ticket: ticket,
            wsColor: wsColor,
            onClose: onClose ?? () {},
          ),
          DetailTabBar(current: tab),
          Expanded(
            // The refresh bar overlays the body's top edge rather than
            // reserving a strip, which would show as a band of the panel's
            // colour above the body's tinted ground.
            child: Stack(
              children: [
                Positioned.fill(
                  child: DetailTabBody(
                    ticket: ticket,
                    tab: tab,
                    layout: layout,
                  ),
                ),
                if (detailLoading)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(
                      minHeight: context.borders.thick,
                      backgroundColor: Colors.transparent,
                    ),
                  ),
              ],
            ),
          ),
          if (tab == DetailTab.translation)
            TranslationFooter(ticketId: ticketId),
        ],
      );
    }

    return Material(
      // Brightest surface so the slide-over reads as an elevated panel that
      // pops against the dimmed board behind it (white in light mode).
      color: c.card,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: c.border),
            top: BorderSide(color: wsColor, width: context.borders.accent),
          ),
        ),
        child: body,
      ),
    );
  }
}
