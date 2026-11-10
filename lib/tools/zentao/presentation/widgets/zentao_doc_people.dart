import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/person_chip.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_context_menu.dart';
import '../../../../core/widgets/app_popup_card.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../domain/entities/zentao_doc_person.dart';

/// "[avatar] ViPham created" / "[avatars] edited" in a document's header, as
/// ZenTao's web shows it. A tap opens a card of these people, each with a
/// button to message them.
class ZenTaoDocPeople extends StatefulWidget {
  const ZenTaoDocPeople({
    super.key,
    required this.accountId,
    required this.people,
    required this.action,
    required this.title,
  });

  final String accountId;
  final List<ZenTaoDocPerson> people;

  /// What they did, after the faces ("created", "edited").
  final String action;

  /// The card's heading ("Created by", "Edited by").
  final String title;

  @override
  State<ZenTaoDocPeople> createState() => _ZenTaoDocPeopleState();
}

class _ZenTaoDocPeopleState extends State<ZenTaoDocPeople> {
  final _menu = MenuController();

  /// More faces than this collapse into the stack's last one.
  static const _maxFaces = 3;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final people = widget.people;
    if (people.isEmpty) return const SizedBox.shrink();
    final face = context.sizes.iconLg;
    final shown = people.take(_maxFaces).toList();
    // Faces overlap by a third, as a stack.
    final step = face * 2 / 3;

    return MenuAnchor(
      controller: _menu,
      style: appMenuAnchorStyle,
      alignmentOffset: Offset(0, s.xs),
      menuChildren: [
        _PeopleCard(
          accountId: widget.accountId,
          title: widget.title,
          people: people,
        ),
      ],
      builder: (context, controller, _) => HoverSurface(
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
        borderRadius: BorderRadius.circular(context.radii.pill),
        padding: EdgeInsets.fromLTRB(s.xxs, s.xxs, s.lg, s.xxs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: face + step * (shown.length - 1),
              height: face,
              child: Stack(
                children: [
                  for (var i = 0; i < shown.length; i++)
                    Positioned(
                      left: step * i,
                      top: 0,
                      child: Container(
                        width: face,
                        height: face,
                        // A ring in the page colour parts overlapping faces;
                        // the face sits inside it, not under it.
                        padding: EdgeInsets.all(s.xxs),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c.card,
                        ),
                        child: _Face(
                          accountId: widget.accountId,
                          person: shown[i],
                          diameter: face - s.xxs * 2,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(width: s.sm),
            if (people.length == 1) ...[
              Text(
                people.single.displayName,
                maxLines: 1,
                softWrap: false,
                style: context.typography.secondaryStrong.copyWith(
                  color: c.textPrimary,
                ),
              ),
              SizedBox(width: s.xs),
            ] else if (people.length > _maxFaces) ...[
              Text(
                '+${people.length - _maxFaces}',
                style: context.typography.secondary.copyWith(
                  color: c.textSecondary,
                ),
              ),
              SizedBox(width: s.xs),
            ],
            Text(
              widget.action,
              maxLines: 1,
              softWrap: false,
              style: context.typography.secondary.copyWith(
                color: c.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeopleCard extends ConsumerWidget {
  const _PeopleCard({
    required this.accountId,
    required this.title,
    required this.people,
  });

  final String accountId;
  final String title;
  final List<ZenTaoDocPerson> people;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final chatButton = ref.watch(personChatButtonBuilderProvider);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: context.sizes.dialogSm),
      child: AppPopupCard(
        padding: EdgeInsets.symmetric(vertical: s.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(s.xl, 0, s.xl, s.sm),
              child: Text(
                title,
                style: context.typography.captionStrong.copyWith(
                  color: c.textTertiary,
                ),
              ),
            ),
            for (final person in people)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: s.xl, vertical: s.sm),
                child: Row(
                  children: [
                    _Face(
                      accountId: accountId,
                      person: person,
                      diameter: context.sizes.controlMd,
                    ),
                    SizedBox(width: s.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            person.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.typography.bodyStrong.copyWith(
                              color: c.textPrimary,
                            ),
                          ),
                          if (person.name != null)
                            Text(
                              person.account,
                              style: context.typography.caption.copyWith(
                                color: c.textTertiary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (chatButton != null) ...[
                      SizedBox(width: s.lg),
                      chatButton(
                        context,
                        accountId: accountId,
                        name: person.account,
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A person's chat photo (by login), or their initial without chat.
class _Face extends ConsumerWidget {
  const _Face({
    required this.accountId,
    required this.person,
    required this.diameter,
  });

  final String accountId;
  final ZenTaoDocPerson person;
  final double diameter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatar = ref.watch(personAvatarBuilderProvider);
    return avatar != null
        ? avatar(
            context,
            accountId: accountId,
            name: person.account,
            diameter: diameter,
          )
        : UserAvatar(name: person.displayName, diameter: diameter);
  }
}
