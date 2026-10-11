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

/// One notification: the linked object's kind and title (bold while unread),
/// who did what, and its reference and time, on a card. Unread cards take
/// a faint accent tint, an accent border and a dot; read/unread and delete appear on hover so the list
/// stays calm. Tapping opens the object.
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
                          hasTitle ? title : n.summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: (unread ? t.bodyStrong : t.body).copyWith(
                            color: unread ? c.textPrimary : c.textSecondary,
                          ),
                        ),
                        if (hasTitle) ...[
                          SizedBox(height: s.xxs),
                          Text(
                            n.summary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.bodySm.copyWith(color: c.textSecondary),
                          ),
                        ],
                        SizedBox(height: s.xs),
                        _Meta(notification: n),
                      ],
                    ),
                  ),
                  SizedBox(width: s.sm),
                  SizedBox(
                    // Room for the two hover actions, so revealing them
                    // never reflows the text.
                    width: context.sizes.controlSm * 2,
                    child: Align(
                      alignment: Alignment.topRight,
                      child: _hover
                          ? _Actions(notification: n)
                          : unread
                          ? Padding(
                              padding: EdgeInsets.all(s.sm),
                              child: Container(
                                width: s.md,
                                height: s.md,
                                decoration: BoxDecoration(
                                  color: c.accent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            )
                          : null,
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

/// "Bug #6492 · 14:05" — the object's reference and the time.
class _Meta extends StatelessWidget {
  const _Meta({required this.notification});

  final ZenTaoNotification notification;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final t = context.typography;
    final n = notification;
    final at = n.createdAt?.toLocal();
    final type = n.objectType;
    final ref = switch ((type, n.objectId)) {
      (final type?, final id?) =>
        '${type[0].toUpperCase()}${type.substring(1)} #$id',
      (null, final id?) => '#$id',
      _ => null,
    };
    return Row(
      children: [
        if (ref != null) ...[
          Text(ref, style: t.monoSm.copyWith(color: c.textTertiary)),
          if (at != null)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: s.sm),
              child: Text(
                '·',
                style: t.caption.copyWith(color: c.textTertiary),
              ),
            ),
        ],
        if (at != null)
          Text(
            DateFormat('HH:mm').format(at),
            style: t.caption.copyWith(color: c.textTertiary),
          ),
      ],
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
