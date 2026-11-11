import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_borders.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/tools/tool_registry_provider.dart';
import 'detail_providers.dart';
import 'widgets/detail_header.dart';
import 'widgets/detail_tab_bar.dart';
import 'widgets/detail_tab_body.dart';
import 'widgets/translation_footer.dart';

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
    final tab = ref.watch(detailTabProvider(ticketId));
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
          DetailTabBar(ticketId: ticketId, current: tab),
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
