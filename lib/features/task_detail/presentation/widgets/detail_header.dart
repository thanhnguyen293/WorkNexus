import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/platform/open_external.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/semantic.dart';
import '../../../../core/util/priority_labels.dart';
import '../../../../core/widgets/badges.dart';
import '../../../../core/widgets/tinted_pill.dart';
import '../../../../l10n/app_localizations.dart';
import '../ticket_actions.dart';

/// The detail panel header: workspace + provider identity, title, actions.
class DetailHeader extends ConsumerWidget {
  const DetailHeader({
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
    final lookups = ref.watch(lookupsProvider);
    final account = lookups.accounts[ticket.accountId];
    final ws = account == null ? null : lookups.workspaces[account.workspaceId];
    final l = AppL10n.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
        context.spacing.xl3,
        context.spacing.xl2,
        context.spacing.xl3,
        context.spacing.xl,
      ),
      decoration: BoxDecoration(border: Border(bottom: context.hairlineSide)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              WorkspaceBadge(
                wsColor,
                ws?.shortCode ?? '?',
                big: true,
                iconKey: ws?.iconKey,
              ),
              SizedBox(width: context.spacing.md),
              Text(
                ws?.isPersonal == true ? l.personal : (ws?.name ?? ''),
                style: context.typography.bodySm.copyWith(
                  fontWeight: FontWeight.w600,
                  color: wsColor,
                ),
              ),
              const Spacer(),
              if (ticket.url != null && ticket.url!.isNotEmpty) ...[
                _CopyLinkButton(url: ticket.url!),
                SizedBox(width: context.spacing.md),
                _HeaderIconButton(
                  icon: Icons.open_in_new,
                  tooltip: 'Open in browser',
                  onTap: () => openExternally(ticket.url!),
                ),
                SizedBox(width: context.spacing.md),
              ],
              _HeaderIconButton(
                icon: Icons.close,
                tooltip: 'Close',
                onTap: onClose,
              ),
            ],
          ),
          SizedBox(height: context.spacing.lg),
          Row(
            children: [
              // ProviderBadge(ticket.providerType, big: true),
              // SizedBox(width: context.spacing.sm),
              Text(
                ticketRef(
                  ticket.providerType,
                  ticket.externalKey,
                  ticket.externalType,
                ),
                style: context.typography.mono.copyWith(color: c.textSecondary),
              ),
              if (hasExplicitPriority(ticket)) ...[
                SizedBox(width: context.spacing.sm),
                PriorityTag(ticket.providerType, ticket.priority),
              ],
              if (ticket.severity != null) ...[
                SizedBox(width: context.spacing.sm),
                SeverityTag(ticket.severity),
              ],
            ],
          ),
          SizedBox(height: context.spacing.md),
          Text(
            ticket.title,
            style: context.typography.detailTitle.copyWith(
              color: c.textPrimary,
            ),
          ),
          TicketActionsBar(ticket: ticket),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(context.radii.sm),
        child: Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.surfaceSubtle,
            borderRadius: BorderRadius.circular(context.radii.sm),
            border: Border.all(color: c.border),
          ),
          child: Icon(icon, size: 15, color: c.textSecondary),
        ),
      ),
    );
  }
}

/// A header icon button that copies [url] to the clipboard, briefly showing a
/// check mark + "Copied!" tooltip as confirmation.
class _CopyLinkButton extends StatefulWidget {
  const _CopyLinkButton({required this.url});
  final String url;

  @override
  State<_CopyLinkButton> createState() => _CopyLinkButtonState();
}

class _CopyLinkButtonState extends State<_CopyLinkButton> {
  bool _copied = false;
  Timer? _resetCopied;

  @override
  void dispose() {
    _resetCopied?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.url));
    if (!mounted) return;
    setState(() => _copied = true);
    _resetCopied?.cancel();
    _resetCopied = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return _HeaderIconButton(
      icon: _copied ? Icons.check : Icons.link,
      tooltip: _copied ? l.linkCopied : l.copyLink,
      onTap: _copy,
    );
  }
}
