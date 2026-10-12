import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/zentao_kind_icon.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/zentao_notification.dart';
import '../util/notification_actions.dart';

/// One notification, read top-down by what matters: who did what (the
/// line to scan, bold while unread), then the ticket it was done to (its
/// number and title, quieter), with the time at the top right. Unread cards
/// take a faint accent tint, an accent border and a dot; read/unread and
/// delete replace the time on hover so the list stays calm. Tapping opens
/// the object.
class NotificationCard extends ConsumerStatefulWidget {
  const NotificationCard({super.key, required this.notification});

  final ZenTaoNotification notification;

  @override
  ConsumerState<NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends ConsumerState<NotificationCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final t = context.typography;
    final n = widget.notification;
    final title = n.objectTitle;
    final hasTitle = title != null && title.isNotEmpty;
    final unread = !n.read;
    return Padding(
      padding: EdgeInsets.only(bottom: s.md),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Material(
          color: unread ? c.mix(c.surface, c.accent, 0.07) : c.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(context.radii.lg),
            side: unread
                ? BorderSide(color: c.mixT(c.accent, 0.35))
                : context.hairlineSide,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            mouseCursor: WidgetStateMouseCursor.clickable,
            onTap: () => openNotification(context, ref, n),
            borderRadius: BorderRadius.circular(context.radii.lg),
            child: Padding(
              padding: EdgeInsets.fromLTRB(s.lg, s.lg, s.sm, s.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ZenTaoKindIcon(n.objectType, large: true),
                  SizedBox(width: s.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          n.summary.isEmpty && hasTitle ? title : n.summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: t.cardTitle.copyWith(
                            fontWeight: unread
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: c.textPrimary,
                          ),
                        ),
                        if (hasTitle || n.objectId != null) ...[
                          SizedBox(height: s.xs),
                          _TicketLine(notification: n),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(width: s.sm),
                  SizedBox(
                    // Room for the two hover actions, so swapping them in for
                    // the time never reflows the text.
                    width: context.sizes.controlSm * 2,
                    child: Align(
                      alignment: Alignment.topRight,
                      child: _hover
                          ? _Actions(notification: n)
                          : _TimeAndDot(notification: n),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "#6492 Feed: video autoplay…" — the ticket the event was about, its
/// number set off in mono; the kind is the icon's to show.
class _TicketLine extends StatelessWidget {
  const _TicketLine({required this.notification});

  final ZenTaoNotification notification;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typography;
    final n = notification;
    final title = n.objectTitle;
    return Text.rich(
      TextSpan(
        children: [
          if (n.objectId case final id?)
            TextSpan(
              text: '#$id  ',
              style: t.monoSm.copyWith(color: c.textTertiary),
            ),
          if (title != null && title.isNotEmpty) TextSpan(text: title),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: t.paragraphSm.copyWith(color: c.textSecondary),
    );
  }
}

/// The time at the card's top right, and under it the unread dot.
class _TimeAndDot extends StatelessWidget {
  const _TimeAndDot({required this.notification});

  final ZenTaoNotification notification;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final at = notification.createdAt?.toLocal();
    return Padding(
      padding: EdgeInsets.only(top: s.xxs, right: s.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (at != null)
            Text(
              DateFormat('HH:mm').format(at),
              style: context.typography.meta.copyWith(color: c.textTertiary),
            ),
          if (!notification.read) ...[
            SizedBox(height: s.sm),
            Container(
              width: s.md,
              height: s.md,
              decoration: BoxDecoration(
                color: c.accent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({required this.notification});

  final ZenTaoNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final n = notification;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIconButton(
          size: AppIconButtonSize.small,
          tooltip: n.read ? l.notificationsMarkUnread : l.notificationsMarkRead,
          icon: n.read ? LucideIcons.circle300 : LucideIcons.circleCheck300,
          onPressed: () => runNotificationCommand(
            context,
            ref,
            (r) => n.read
                ? r.markUnread(n.accountId, n.id)
                : r.markRead(n.accountId, id: n.id),
          ),
        ),
        AppIconButton(
          size: AppIconButtonSize.small,
          tooltip: l.notificationsDelete,
          icon: LucideIcons.trash300,
          onPressed: () => runNotificationCommand(
            context,
            ref,
            (r) => r.delete(n.accountId, n.id),
          ),
        ),
      ],
    );
  }
}
