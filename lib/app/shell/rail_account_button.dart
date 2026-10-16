import 'package:flutter/material.dart';

import '../../core/domain/entities/account.dart';
import '../../core/domain/value_objects/provider_type.dart';
import '../../core/widgets/app_rail_labeled_button.dart';
import '../../core/widgets/badges.dart';
import '../../core/widgets/unread_badge.dart';

/// Single account button in the navigation rail (design §8, specs S3.1, S3.2).
/// Displays [ProviderBadge], provider/handle label, active indicator,
/// and unread chat badge for ZenTao.
class RailAccountButton extends StatelessWidget {
  const RailAccountButton({
    super.key,
    required this.account,
    required this.isSelected,
    required this.hasDuplicateProvider,
    required this.onTap,
    this.unreadCount = 0,
  });

  final Account account;
  final bool isSelected;
  final bool hasDuplicateProvider;
  final VoidCallback onTap;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final label = hasDuplicateProvider
        ? account.handle
        : account.providerType.displayName;
    final tooltip = '${account.providerType.displayName} · ${account.handle}';
    final showUnread =
        account.providerType == ProviderType.zentao && unreadCount > 0;

    return AppRailLabeledButton(
      leading: ProviderBadge(account.providerType, big: true),
      label: label,
      tooltip: tooltip,
      selected: isSelected,
      onTap: onTap,
      badge: showUnread ? UnreadBadge(count: unreadCount) : null,
    );
  }
}
