import 'package:flutter/material.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';

/// Width of a panel beside the chat (info, pinned messages).
const double kChatSidePanelWidth = 340;

/// The frame of a panel beside the chat: a titled header with a close
/// button above [child].
class ChatSidePanelFrame extends StatelessWidget {
  const ChatSidePanelFrame({
    super.key,
    required this.title,
    required this.onClose,
    required this.child,
  });

  final String title;
  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    return Container(
      width: kChatSidePanelWidth,
      decoration: BoxDecoration(
        color: c.background,
        border: Border(left: context.hairlineSide),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(s.xl3, s.md, s.md, s.md),
            decoration: BoxDecoration(
              color: c.surface,
              border: Border(bottom: context.hairlineSide),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.title.copyWith(
                      color: c.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: AppL10n.of(context).chatClosePanel,
                  onPressed: onClose,
                  icon: Icon(Icons.close, color: c.textSecondary),
                ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// One section of the panel: a surface card with a hairline border.
class ChatPanelCard extends StatelessWidget {
  const ChatPanelCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    return Container(
      margin: EdgeInsets.only(bottom: s.xl),
      padding: padding ?? EdgeInsets.all(s.xl3),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(context.radii.lg),
        border: Border.fromBorderSide(context.hairlineSide),
      ),
      child: child,
    );
  }
}
