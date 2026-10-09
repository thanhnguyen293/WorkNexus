import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/usecases/order_chat_roles.dart';
import 'chat_labels.dart';

/// Whether a user with [role] shows under the role tab [filter] (null: all).
bool chatRoleMatches(String? filter, String? role) =>
    filter == null || (role?.trim() ?? '') == filter;

/// Tabs above a list of people: "All", then one per role among [roles] (the
/// people's role codes), most senior first, each with how many have it (a
/// count pill). A
/// scrollable tab bar, so the picked tab scrolls into view; hidden when
/// everyone shares one role.
class ChatRoleTabs extends StatefulWidget {
  const ChatRoleTabs({
    super.key,
    required this.roles,
    required this.selected,
    required this.onSelect,
    this.serverNames = const {},
  });

  final List<String?> roles;

  /// The server's names for roles an admin added (see [chatRoleLabel]).
  final Map<String, String> serverNames;

  /// The role code shown; null for everyone.
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  State<ChatRoleTabs> createState() => _ChatRoleTabsState();
}

class _ChatRoleTabsState extends State<ChatRoleTabs>
    with TickerProviderStateMixin {
  TabController? _tabs;

  @override
  void dispose() {
    _tabs?.dispose();
    super.dispose();
  }

  /// A controller for [length] tabs on [index]; replaced only when the
  /// number of tabs changes (people loaded, another chat).
  TabController _controller(int length, int index) {
    final current = _tabs;
    if (current != null && current.length == length) {
      // Follows a pick made elsewhere; a tap here has moved it already.
      if (current.index != index) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && current == _tabs) current.animateTo(index);
        });
      }
      return current;
    }
    current?.dispose();
    return _tabs = TabController(
      length: length,
      initialIndex: index,
      vsync: this,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final c = context.colors;
    final s = context.spacing;
    final roles = widget.roles;
    final order = const OrderChatRoles()(roles);
    if (order.length < 2) return const SizedBox.shrink();
    int count(String code) =>
        roles.where((r) => chatRoleMatches(code, r)).length;
    String label(String code) => code.isEmpty
        ? l.chatRoleNone
        : chatRoleLabel(context, code, serverNames: widget.serverNames);
    final selected = widget.selected;
    final index = selected == null ? 0 : order.indexOf(selected) + 1;
    // One weight for picked and not: a bolder picked tab would widen and
    // push the others along.
    final text = context.typography.secondary.copyWith(
      fontWeight: FontWeight.w600,
    );
    final radius = BorderRadius.circular(context.radii.md);
    return TabBar(
      controller: _controller(order.length + 1, index < 0 ? 0 : index),
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      dividerColor: Colors.transparent,
      indicatorSize: TabBarIndicatorSize.tab,
      indicator: BoxDecoration(color: c.selectionFill, borderRadius: radius),
      splashBorderRadius: radius,
      labelColor: c.accent,
      unselectedLabelColor: c.textSecondary,
      labelStyle: text,
      unselectedLabelStyle: text,
      labelPadding: EdgeInsets.symmetric(horizontal: s.lg),
      padding: EdgeInsets.zero,
      onTap: (i) => widget.onSelect(i == 0 ? null : order[i - 1]),
      tabs: [
        Tab(
          height: s.xl6 * 0.75,
          child: _TabLabel(label: l.chatTabAll, count: roles.length),
        ),
        for (final code in order)
          Tab(
            height: s.xl6 * 0.75,
            child: _TabLabel(label: label(code), count: count(code)),
          ),
      ],
    );
  }
}

/// A tab's name with its count as a small pill beside it, tinted with the
/// tab's own text colour (accent when picked).
class _TabLabel extends StatelessWidget {
  const _TabLabel({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final ink =
        DefaultTextStyle.of(context).style.color ??
        context.colors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        SizedBox(width: s.sm),
        DecoratedBox(
          decoration: BoxDecoration(
            color: ink.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(context.radii.pill),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: s.sm, vertical: s.xxs),
            child: Text(
              '$count',
              style: context.typography.captionStrong.copyWith(color: ink),
            ),
          ),
        ),
      ],
    );
  }
}
