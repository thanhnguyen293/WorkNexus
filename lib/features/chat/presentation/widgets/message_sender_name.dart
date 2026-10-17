import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import 'chat_profile_tap.dart';

/// A message sender's name, tapping through to their profile. With [time] it
/// is the header over a run (ZenTao): the name with the run's time beside it.
class MessageSenderName extends StatelessWidget {
  const MessageSenderName({
    super.key,
    required this.accountId,
    required this.userId,
    required this.name,
    required this.color,
    this.labelSize,
    this.time,
    this.timeColor,
    this.timeSize,
  });

  final String accountId;
  final int userId;
  final String name;
  final Color color;
  final double? labelSize;

  /// When set, shown beside the name.
  final DateTime? time;
  final Color? timeColor;
  final double? timeSize;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      name,
      style: context.typography.captionStrong.copyWith(
        color: color,
        fontSize: labelSize,
        fontWeight: labelSize == null ? null : FontWeight.w600,
      ),
    );
    final time = this.time;
    return ChatProfileTap(
      accountId: accountId,
      userId: userId,
      name: name,
      showName: false,
      child: time == null
          ? label
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: label),
                SizedBox(width: context.spacing.md),
                Text(
                  DateFormat('HH:mm').format(time),
                  style: context.typography.captionSm.copyWith(
                    color: timeColor,
                    fontSize: timeSize,
                  ),
                ),
              ],
            ),
    );
  }
}
