import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/platform/open_external.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import 'detail_header_icon_button.dart';

/// Panel-level (non-state-changing) actions in a two-pane detail header: refresh,
/// copy link, open in browser, edit (on the provider's web page), and close the
/// panel — all rendered with the shared [DetailHeaderIconButton] so they match the
/// standard panel header. State transitions (merge / rebase / approve / close)
/// live in the gated merge panel + composer, so they aren't duplicated here.
class DetailPanelHeaderActions extends StatelessWidget {
  const DetailPanelHeaderActions({
    super.key,
    required this.ticket,
    required this.onSync,
    required this.onClosePanel,
  });

  final Ticket ticket;
  final VoidCallback onSync;
  final VoidCallback onClosePanel;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final url = ticket.url;
    final hasUrl = url != null && url.isNotEmpty;
    return Wrap(
      spacing: context.spacing.md,
      runSpacing: context.spacing.md,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        DetailHeaderIconButton(
          icon: LucideIcons.refreshCw300,
          tooltip: l.refresh,
          onTap: onSync,
        ),
        if (hasUrl) DetailHeaderCopyLinkButton(url: url),
        if (hasUrl)
          DetailHeaderIconButton(
            icon: LucideIcons.squareArrowOutUpRight300,
            tooltip: l.openInBrowser,
            onTap: () => openExternally(url),
          ),
        if (hasUrl)
          DetailHeaderIconButton(
            icon: LucideIcons.pencil300,
            tooltip: l.edit,
            onTap: () => openExternally('$url/edit'),
          ),
        DetailHeaderIconButton(
          icon: LucideIcons.x300,
          tooltip: l.close,
          onTap: onClosePanel,
        ),
      ],
    );
  }
}
