import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/provider_type.dart';

/// Whether [Ticket] is assigned to [Account]'s own user: its assignee is the
/// account's handle. ZenTao stores the assignee's login; GitLab and GitHub
/// store display names, so their assignees' logins are matched (with the
/// display name as a fallback for items synced before logins were kept).
class IsAssignedToMe {
  const IsAssignedToMe();

  bool call(Ticket ticket, Account account) {
    final me = account.handle.trim().toLowerCase();
    if (me.isEmpty) return false;
    bool isMe(String? name) {
      if (name == null || name.trim().isEmpty) return false;
      final n = name.trim().toLowerCase();
      if (n == me) return true;
      final cleanN = n.replaceAll(RegExp(r'[\._\s\-]'), '');
      final cleanMe = me.replaceAll(RegExp(r'[\._\s\-]'), '');
      // Separators may differ (`thanh.nguyen` / `thanh_nguyen`); a mere
      // prefix is someone else (`thanh` is not `thanhle`).
      return cleanN.isNotEmpty && cleanN == cleanMe;
    }

    return switch (ticket.providerType) {
      ProviderType.zentao => isMe(ticket.assignee),
      ProviderType.gitlab || ProviderType.github =>
        isMe(ticket.assignee) || _logins(ticket.providerEntity).any(isMe),
      _ => false,
    };
  }

  static List<String> _logins(TicketProviderEntity? entity) => switch (entity) {
    GitLabItemEntity(:final assigneeLogins) => assigneeLogins,
    GitHubItemEntity(:final assigneeLogins) => assigneeLogins,
    _ => const [],
  };
}
