import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_context_menu.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../detail_providers.dart';

/// The header's "⋯" menu: the panel actions used now and then (refresh, copy
/// link), kept out of the header row so the title has less to compete with.
class DetailHeaderMoreButton extends ConsumerWidget {
  const DetailHeaderMoreButton({super.key, required this.ticket});

  final Ticket ticket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    return AppIconButton(
      outlined: true,
      icon: LucideIcons.ellipsis300,
      tooltip: l.more,
      onPressed: () => _open(context, ref),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final l = AppL10n.of(context);
    final url = ticket.url ?? '';
    final box = context.findRenderObject() as RenderBox?;
    final at =
        box?.localToGlobal(Offset(0, box.size.height + context.spacing.xs)) ??
        Offset.zero;
    final picked = await showAppContextMenu(
      context,
      at: at,
      entries: [
        AppMenuEntry(icon: LucideIcons.refreshCw300, label: l.refresh),
        if (url.isNotEmpty)
          AppMenuEntry(icon: LucideIcons.link300, label: l.copyLink),
      ],
    );
    if (!context.mounted) return;
    switch (picked) {
      case 0:
        ref.invalidate(ticketDetailSyncProvider(ticket.id));
      case 1:
        await Clipboard.setData(ClipboardData(text: url));
        if (context.mounted) showAppSnack(context, l.linkCopied);
    }
  }
}
