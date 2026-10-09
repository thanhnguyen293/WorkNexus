/// A ZenTao user's role (`zt_user.role`), from ZenTao's default role list.
/// A role does not grant rights (privilege groups do): it describes the job
/// and orders user lists. Admins can add their own codes, which stay as they
/// are (see [ChatRole.fromCode]).
enum ChatRole {
  dev,
  qa,
  pm,
  po,
  td,
  pd,
  qd,
  top,
  others;

  /// The role for a stored code; null for an empty or admin-defined one.
  static ChatRole? fromCode(String? code) {
    final key = code?.trim();
    return values.where((r) => r.name == key).firstOrNull;
  }

  /// How senior the role is, for the "verified" check beside the avatar;
  /// null for engineers (dev, qa) and "others", who get none.
  ChatRoleRank? get rank => switch (this) {
    dev || qa || others => null,
    pm || po => ChatRoleRank.lead,
    td || pd || qd => ChatRoleRank.manager,
    top => ChatRoleRank.executive,
  };
}

/// Seniority of a leading role, lowest first.
enum ChatRoleRank {
  /// Leads a project or a product (project manager, product owner).
  lead,

  /// Heads a department (technical, product or test manager).
  manager,

  /// Senior management.
  executive,
}

/// Role codes admins often add beyond ZenTao's defaults, with their rank
/// (null: no "verified" check — a specialist, like dev and qa).
const Map<String, ChatRoleRank?> kExtraRoleRanks = {
  'opm': ChatRoleRank.manager,
  'ui': null,
  'designer': null,
  'ux': null,
  'op': null,
  'ops': null,
  'ba': null,
  'devops': null,
};

/// The rank of any role code — a default role or a common added one; null
/// for no check (specialists, "others", unknown codes).
ChatRoleRank? chatRoleRankOf(String? code) {
  final key = code?.trim().toLowerCase() ?? '';
  return ChatRole.fromCode(key)?.rank ?? kExtraRoleRanks[key];
}

/// The role codes holding [rank], in the defaults' order then the added
/// ones — what the check legend lists for that colour.
List<String> chatRoleCodesOf(ChatRoleRank rank) => [
  for (final role in ChatRole.values)
    if (role.rank == rank) role.name,
  for (final MapEntry(:key, :value) in kExtraRoleRanks.entries)
    if (value == rank) key,
];
