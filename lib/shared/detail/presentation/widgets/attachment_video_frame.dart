import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/util/zentao_labels.dart';
import '../detail_providers.dart';

/// A video attached to a timeline entry, drawn as chat draws one: a 16:9
/// frame with a still (when one can be made), its name and size along the
/// top and a play disc in the middle. Clicking it opens the viewer.
class AttachmentVideoFrame extends ConsumerWidget {
  const AttachmentVideoFrame({
    super.key,
    required this.ticket,
    required this.attachment,
    required this.onTap,
  });

  final Ticket ticket;
  final TicketAttachment attachment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final still = ref
        .watch(attachmentThumbnailProvider((ticket, attachment)))
        .value;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: context.sizes.mediaPreview),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(context.radii.lg),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Black until a still is ready, as a player would be.
              ColoredBox(color: c.scrim),
              if (still != null) Image.memory(still, fit: BoxFit.cover),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: _NameBar(
                  name: attachment.title,
                  size: formatFileSize(attachment.size),
                ),
              ),
              const Center(child: _PlayDisc()),
              Material(
                type: MaterialType.transparency,
                child: InkWell(
                  mouseCursor: WidgetStateMouseCursor.clickable,
                  onTap: onTap,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The name and size over a fade, so they read on any still.
class _NameBar extends StatelessWidget {
  const _NameBar({required this.name, required this.size});

  final String name;
  final String? size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            c.scrim.withValues(alpha: 0.6),
            c.scrim.withValues(alpha: 0),
          ],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(s.md, s.md, s.md, s.xl3),
        child: Row(
          children: [
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.typography.captionStrong.copyWith(
                  color: c.onScrim,
                ),
              ),
            ),
            if (size != null) ...[
              SizedBox(width: s.md),
              Text(
                size!,
                style: context.typography.caption.copyWith(
                  color: c.onScrim.withValues(alpha: 0.85),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlayDisc extends StatelessWidget {
  const _PlayDisc();

  @override
  Widget build(BuildContext context) => Container(
    width: context.sizes.stateTile,
    height: context.sizes.stateTile,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: context.colors.scrim.withValues(alpha: 0.5),
      shape: BoxShape.circle,
    ),
    // Optically centred: a triangle's weight sits left of its box.
    child: Padding(
      padding: EdgeInsets.only(left: context.spacing.xxs),
      child: Icon(
        LucideIcons.play300,
        size: context.sizes.iconLg,
        color: context.colors.onScrim,
      ),
    ),
  );
}
