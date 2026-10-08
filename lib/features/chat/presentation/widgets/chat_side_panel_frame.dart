import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';

/// Width of a panel beside the chat (info, pinned messages).
const double kChatSidePanelWidth = 340;

/// Height of the chat header and of every side panel's header, so their
/// bottom borders line up (a large avatar plus vertical padding).
const double kChatHeaderHeight = 68;

/// The frame of a panel beside the chat: a titled header with a close
/// button above [child].
class ChatSidePanelFrame extends StatelessWidget {
  const ChatSidePanelFrame({
    super.key,
    required this.title,
    required this.onClose,
    required this.child,
    this.width = kChatSidePanelWidth,
    this.closeTooltip,
    this.onBack,
  });

  /// Shows a back arrow before the title (sub-panels of the chat info).
  final VoidCallback? onBack;

  final double width;

  /// Close button tooltip; defaults to "Close".
  final String? closeTooltip;
  final String title;

  /// Null hides the close button (the info panel while there is room).
  final VoidCallback? onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: c.background,
        border: Border(left: context.hairlineSide),
      ),
      child: Column(
        children: [
          Container(
            height: kChatHeaderHeight,
            padding: EdgeInsets.only(
              left: onBack == null ? s.xl3 : s.xs,
              right: s.md,
            ),
            decoration: BoxDecoration(
              color: c.surface,
              border: Border(bottom: context.hairlineSide),
            ),
            child: Row(
              children: [
                if (onBack case final back?)
                  IconButton(
                    tooltip: AppL10n.of(context).chatBackToInfo,
                    onPressed: back,
                    icon: Icon(
                      PhosphorIconsLight.arrowLeft,
                      color: c.textSecondary,
                    ),
                  ),
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
                if (onClose case final close?)
                  IconButton(
                    tooltip: closeTooltip ?? AppL10n.of(context).chatClosePanel,
                    onPressed: close,
                    icon: Icon(PhosphorIconsLight.x, color: c.textSecondary),
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
      margin: EdgeInsets.only(bottom: s.md),
      padding: padding ?? EdgeInsets.all(s.xl),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(context.radii.lg),
        border: Border.fromBorderSide(context.hairlineSide),
      ),
      child: child,
    );
  }
}
