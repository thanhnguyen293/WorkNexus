import '../value_objects/chat_role.dart';

/// The role codes present among some users, most senior first — the order
/// of the role tabs: senior management, the managers, project/product
/// leads, engineers, "others", then roles an admin added (by name) and, last,
/// users without a role (`''`).
class OrderChatRoles {
  const OrderChatRoles();

  static const _known = [
    ChatRole.top,
    ChatRole.td,
    ChatRole.pd,
    ChatRole.qd,
    ChatRole.pm,
    ChatRole.po,
    ChatRole.dev,
    ChatRole.qa,
    ChatRole.others,
  ];

  /// [codes] trimmed; null and blank both mean "no role" (`''`).
  List<String> call(Iterable<String?> codes) {
    final present = {for (final code in codes) code?.trim() ?? ''};
    return [
      for (final role in _known)
        if (present.contains(role.name)) role.name,
      ...(present
          .where((c) => c.isNotEmpty && ChatRole.fromCode(c) == null)
          .toList()
        ..sort()),
      if (present.contains('')) '',
    ];
  }
}
