import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/value_objects/message_content.dart';
import 'chat_labels.dart';

/// A pinned message's content in its card: two lines of preview, after a
/// link glyph when the message carries a link.
class PinnedCardPreview extends StatelessWidget {
  const PinnedCardPreview({super.key, required this.message});

  final ChatMessage message;

  static final _url = RegExp(r'https?://', caseSensitive: false);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final text = message.deleted
        ? AppL10n.of(context).chatRetracted
        : chatPreview(context, message);
    final isLink =
        !message.deleted &&
        message.content is TextContent &&
        _url.hasMatch((message.content as TextContent).text);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isLink) ...[
          Icon(LucideIcons.link300, size: s.xl3, color: c.textSecondary),
          SizedBox(width: s.md),
        ],
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.typography.body.copyWith(color: c.textPrimary),
          ),
        ),
      ],
    );
  }
}
