import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hover_surface.dart';

/// Single item in chat search results.
class ChatSearchResultTile extends StatelessWidget {
  const ChatSearchResultTile({
    super.key,
    required this.chatName,
    required this.sender,
    required this.time,
    required this.preview,
    required this.query,
    required this.onTap,
    this.isActive = false,
  });

  final String chatName;
  final String sender;
  final String time;
  final String preview;
  final String query;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isActive ? c.accent.withValues(alpha: 0.12) : null,
        border: isActive
            ? Border(left: BorderSide(color: c.accent, width: 3))
            : null,
      ),
      child: HoverSurface(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.spacing.sm,
            vertical: context.spacing.xs,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      chatName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.typography.secondary.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: c.accent,
                      ),
                    ),
                  ),
                  Text(
                    time,
                    style: context.typography.secondary.copyWith(
                      fontSize: 10,
                      color: c.textTertiary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                sender,
                style: context.typography.secondary.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: c.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.typography.body.copyWith(
                  fontSize: 12,
                  color: c.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
