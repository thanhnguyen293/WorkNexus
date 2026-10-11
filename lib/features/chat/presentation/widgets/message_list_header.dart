import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/inline_status.dart';
import '../../../../l10n/app_localizations.dart';

/// Top of the thread: a spinner while earlier messages load (they load on
/// their own), a retry button after a failed load, or the start marker.
class MessageListHeader extends StatelessWidget {
  const MessageListHeader({
    super.key,
    required this.reachedStart,
    required this.isEmpty,
    required this.failed,
    required this.onLoadOlder,
  });

  final bool reachedStart;

  /// No messages to show: the list's empty state (or a load's spinner)
  /// stands in for the marker.
  final bool isEmpty;
  final bool failed;
  final VoidCallback onLoadOlder;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    // An empty chat shows its empty state over the list instead.
    if (isEmpty && !failed) return const SizedBox.shrink();
    if (!reachedStart && !failed) return const AppInlineSpinner();
    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.xl),
      child: Center(
        child: reachedStart
            ? Text(
                l.chatBeginning,
                style: context.typography.caption.copyWith(
                  color: context.colors.textTertiary,
                ),
              )
            : AppButton.textNeutral(
                size: AppButtonSize.small,
                onPressed: onLoadOlder,
                child: Text(l.chatLoadOlder),
              ),
      ),
    );
  }
}
