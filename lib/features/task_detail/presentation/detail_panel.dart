import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/navigation/navigation_providers.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_borders.dart';
import '../../../core/theme/app_colors.dart';
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
    duration: const Duration(milliseconds: 220),
  );
  String? _current;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _close() => ref.read(openTicketIdProvider.notifier).close();

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(openTicketIdProvider, (prev, next) {
      if (next != null) {
        setState(() => _current = next);
        ref.read(detailTabProvider.notifier).set(DetailTab.original);
        _c.forward();
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
    final curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

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
                    : _DetailPanel(ticketId: id, onClose: _close),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DetailPanel extends ConsumerWidget {
  const _DetailPanel({required this.ticketId, required this.onClose});
  final String ticketId;
  final VoidCallback onClose;

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DetailHeader(ticket: ticket, wsColor: wsColor, onClose: onClose),
            DetailTabBar(current: tab),
            SizedBox(
              height: 2,
              child: detailLoading
                  ? LinearProgressIndicator(
                      minHeight: 2,
                      backgroundColor: Colors.transparent,
                      color: c.accent,
                    )
                  : null,
            ),
            Expanded(
              child: DetailTabBody(ticket: ticket, tab: tab, layout: layout),
            ),
            if (tab == DetailTab.translation)
              TranslationFooter(ticketId: ticketId),
          ],
        ),
      ),
    );
  }
}
