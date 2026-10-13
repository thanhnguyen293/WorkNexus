import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/platform/open_external.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../l10n/app_localizations.dart';
import 'detail_header_copy_link_button.dart';

/// Panel-level (non-state-changing) actions in a two-pane detail header: refresh,
/// copy link, open in browser, edit (on the provider's web page), and close the
/// panel — all rendered with [AppIconButton] so they match the standard panel
/// header — plus an optional item-specific [menu].
class DetailPanelHeaderActions extends StatelessWidget {
  const DetailPanelHeaderActions({
    super.key,
    required this.ticket,
    required this.onSync,
    required this.onClosePanel,
    this.menu,
  });

  final Ticket ticket;
  final VoidCallback onSync;
  final VoidCallback onClosePanel;

  /// An item-specific "more" menu (e.g. the MR's state actions), placed just
  /// before the close-panel button.
  final Widget? menu;

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
        AppIconButton(
          outlined: true,
          icon: LucideIcons.refreshCw300,
          tooltip: l.refresh,
          onPressed: onSync,
        ),
        if (hasUrl) DetailHeaderCopyLinkButton(url: url),
        if (hasUrl)
          AppIconButton(
            outlined: true,
            icon: LucideIcons.squareArrowOutUpRight300,
            tooltip: l.openInBrowser,
            onPressed: () => openExternally(url),
          ),
        if (hasUrl)
          AppIconButton(
            outlined: true,
            icon: LucideIcons.pencil300,
            tooltip: l.edit,
            onPressed: () => openExternally('$url/edit'),
          ),
        ?menu,
        AppIconButton(
          outlined: true,
          icon: LucideIcons.x300,
          tooltip: l.close,
          onPressed: onClosePanel,
        ),
      ],
    );
  }
}
