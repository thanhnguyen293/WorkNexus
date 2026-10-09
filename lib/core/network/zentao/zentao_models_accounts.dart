part of 'zentao_models.dart';

/// `POST /tokens` → `{ token }`. The token doubles as the `zentaosid` session id.
@JsonSerializable(createToJson: false)
class ZenTaoTokenResponse {
  const ZenTaoTokenResponse({this.token});
  final String? token;
  factory ZenTaoTokenResponse.fromJson(Map<String, dynamic> json) =>
      _$ZenTaoTokenResponseFromJson(json);
}

/// A user that a ticket can be (re)assigned to (`GET /users`).
@JsonSerializable(createToJson: false)
class ZenTaoUser {
  const ZenTaoUser({this.account, this.realname});
  final String? account;
  final String? realname;
  factory ZenTaoUser.fromJson(Map<String, dynamic> json) =>
      _$ZenTaoUserFromJson(json);
}

/// `GET /users` → `{ users: [...] }`.
@JsonSerializable(createToJson: false)
class ZenTaoUsersResponse {
  const ZenTaoUsersResponse({required this.users});
  @JsonKey(defaultValue: <ZenTaoUser>[])
  final List<ZenTaoUser> users;
  factory ZenTaoUsersResponse.fromJson(Map<String, dynamic> json) =>
      _$ZenTaoUsersResponseFromJson(json);
}

/// One `{ total, <bugs|tasks|stories>: [...] }` group inside the `GET /user`
/// (assigned-to-me) response. The list key varies by kind, so this reads the
/// first list value in the group rather than a fixed key.
class ZenTaoAssignedGroup {
  const ZenTaoAssignedGroup({required this.total, required this.items});
  final int total;
  final List<ZenTaoEntity> items;

  factory ZenTaoAssignedGroup.fromJson(Map<String, dynamic> json) {
    final lists = json.values.whereType<List<Object?>>();
    final list = lists.isEmpty ? const <Object?>[] : lists.first;
    return ZenTaoAssignedGroup(
      total: zentaoInt(json['total']) ?? 0,
      items: [
        for (final e in list)
          if (e is Map) ZenTaoEntity.fromJson(Map<String, dynamic>.from(e)),
      ],
    );
  }
}

/// `GET /user?type=assignedTo&fields=<bug|task|story>` →
/// `{ profile, bug: {...}, task: {...}, story: {...} }`.
@JsonSerializable(createToJson: false)
class ZenTaoAssignedResponse {
  const ZenTaoAssignedResponse({this.bug, this.task, this.story});
  final ZenTaoAssignedGroup? bug;
  final ZenTaoAssignedGroup? task;
  final ZenTaoAssignedGroup? story;

  factory ZenTaoAssignedResponse.fromJson(Map<String, dynamic> json) =>
      _$ZenTaoAssignedResponseFromJson(json);

  /// The group for a ZenTao `fields` value (`bug` / `task` / `story`).
  ZenTaoAssignedGroup? groupFor(String field) => switch (field) {
    'bug' => bug,
    'task' => task,
    'story' => story,
    _ => null,
  };
}
