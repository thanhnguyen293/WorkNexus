import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/navigation/ticket_editor_route.dart';
import '../../../../core/platform/open_external.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/semantic.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/badges.dart';
import '../../../../l10n/app_localizations.dart';
import 'detail_back_button.dart';
import 'detail_header_more_button.dart';

/// The detail header's first row: where the ticket lives (workspace / ref) on
/// the left as quiet context, the panel actions on the right — edit, open in
/// browser, the "⋯" menu, close.
class DetailHeaderTopBar extends ConsumerWidget {
  const DetailHeaderTopBar({
    super.key,
    required this.ticket,
    required this.wsColor,
    required this.onClose,
  });

  final Ticket ticket;
  final Color wsColor;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final lookups = ref.watch(lookupsProvider);
    final account = lookups.accounts[ticket.accountId];
    final ws = account == null ? null : lookups.workspaces[account.workspaceId];
    final url = ticket.url ?? '';
    final quiet = context.typography.bodySm.copyWith(color: c.textTertiary);
    return Row(
      children: [
        const DetailBackButton(),
        Expanded(
          child: Row(
            children: [
              WorkspaceBadge(
                wsColor,
                ws?.shortCode ?? '?',
                iconKey: ws?.iconKey,
              ),
              SizedBox(width: context.spacing.sm),
              Flexible(
                child: Text(
                  ws?.isPersonal == true ? l.personal : (ws?.name ?? ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: quiet.copyWith(color: c.textSecondary),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: context.spacing.sm),
                child: Text('/', style: quiet),
              ),
              Text(
                ticketRef(
                  ticket.providerType,
                  ticket.externalKey,
                  ticket.externalType,
                ),
                style: context.typography.mono.copyWith(color: c.textTertiary),
              ),
            ],
          ),
        ),
        SizedBox(width: context.spacing.lg),
        if (_editRoute(ticket) case final route?) ...[
          AppIconButton(
            outlined: true,
            icon: LucideIcons.pencil300,
            tooltip: l.edit,
            // The editor takes the screen; the detail returns when it closes.
            onPressed: () =>
                ref.read(appNavProvider.notifier).openEditor(route),
          ),
          SizedBox(width: context.spacing.md),
        ],
        if (url.isNotEmpty) ...[
          AppIconButton(
            outlined: true,
            icon: LucideIcons.squareArrowOutUpRight300,
            tooltip: l.openInBrowser,
            onPressed: () => openLinkExternally(url, inApp: false),
          ),
          SizedBox(width: context.spacing.md),
        ],
        DetailHeaderMoreButton(ticket: ticket),
        SizedBox(width: context.spacing.md),
        AppIconButton(
          outlined: true,
          icon: LucideIcons.x300,
          tooltip: l.close,
          onPressed: onClose,
        ),
      ],
    );
  }
}

/// The editor for a ZenTao bug or task; null for anything else.
TicketEditorRoute? _editRoute(Ticket ticket) {
  if (ticket.providerType != ProviderType.zentao) return null;
  return switch (ticket.externalType?.toLowerCase()) {
    'bug' => EditBugRoute(
      accountId: ticket.accountId,
      bugId: ticket.externalKey,
      ticketId: ticket.id,
    ),
    'task' => EditTaskRoute(
      accountId: ticket.accountId,
      taskId: ticket.externalKey,
      ticketId: ticket.id,
    ),
    _ => null,
  };
}
