import 'package:json_annotation/json_annotation.dart';

part 'zentao_models.g.dart';

// ─────────────────────────────────────────────────────────────────────────────
// JSON DTOs for the ZenTao REST v1 API (deserialize-only). ZenTao's payloads are
// loosely typed — numbers arrive as ints or strings, `assignedTo`/`actor` as a
// bare string or an `{account, realname}` object, and `actions` as a list or an
// id-keyed map — so union-shaped fields stay `Object?` (read leniently via the
// helpers in `zentao_normalize.dart`) and numeric fields go through [zentaoInt].
// These DTOs never leave the data layer (rule 3.3): the adapter maps them to
// domain entities at the boundary.
// ─────────────────────────────────────────────────────────────────────────────

/// Lenient int parse: accepts `int`, `num`, or numeric `String` (ZenTao mixes).
int? zentaoInt(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

/// ZenTao returns `actions` as a JSON array or an id-keyed object; normalize
/// both to a chronologically-sorted list of [ZenTaoAction].
List<ZenTaoAction> zentaoActions(Object? raw) {
  final List<Object?> values;
  if (raw is List) {
    values = raw;
  } else if (raw is Map) {
    values = raw.values.toList()
      ..sort((a, b) {
        final ai = a is Map ? (zentaoInt(a['id']) ?? 0) : 0;
        final bi = b is Map ? (zentaoInt(b['id']) ?? 0) : 0;
        return ai.compareTo(bi);
      });
  } else {
    return const [];
  }
  return [
    for (final e in values)
      if (e is Map) ZenTaoAction.fromJson(Map<String, dynamic>.from(e)),
  ];
}

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

/// One entry in a ticket's action/history collection.
@JsonSerializable(createToJson: false)
class ZenTaoAction {
  const ZenTaoAction({
    this.id,
    this.action,
    this.actor,
    this.comment,
    this.date,
    this.extra,
  });

  final Object? id;
  final Object? action;
  final Object? actor; // String | { account, realname }
  final Object? comment;
  final Object? date;
  final Object? extra; // String | object (assignee / resolution / …)

  factory ZenTaoAction.fromJson(Map<String, dynamic> json) =>
      _$ZenTaoActionFromJson(json);

  String get actionType => action?.toString().toLowerCase() ?? '';
  String get commentText => comment?.toString() ?? '';
}

/// A ZenTao bug / task / story object. Fields differ by kind (title vs name,
/// steps vs desc vs spec) and are read leniently by `normalizeZenTao`.
@JsonSerializable(createToJson: false)
class ZenTaoEntity {
  const ZenTaoEntity({
    this.id,
    this.title,
    this.name,
    this.steps,
    this.desc,
    this.description,
    this.spec,
    this.status,
    this.pri,
    this.confirmed,
    this.severity,
    this.keywords,
    this.assignedTo,
    this.openedDate,
    this.lastEditedDate,
    this.productName,
    this.projectName,
    this.executionName,
    this.product,
    this.project,
    this.execution,
    this.actions = const [],
  });

  final Object? id;
  final Object? title;
  final Object? name;
  final Object? steps;
  final Object? desc;
  final Object? description;
  final Object? spec;
  final Object? status;
  @JsonKey(fromJson: zentaoInt)
  final int? pri;
  @JsonKey(fromJson: zentaoInt)
  final int? confirmed;
  @JsonKey(fromJson: zentaoInt)
  final int? severity;
  final Object? keywords;
  final Object? assignedTo; // String | { account, realname }
  final Object? openedDate;
  final Object? lastEditedDate;
  final Object? productName;
  final Object? projectName;
  final Object? executionName;
  final Object? product;
  final Object? project;
  final Object? execution;
  @JsonKey(fromJson: zentaoActions)
  final List<ZenTaoAction> actions;

  factory ZenTaoEntity.fromJson(Map<String, dynamic> json) =>
      _$ZenTaoEntityFromJson(json);

  /// The ZenTao id as a string (`''` when absent).
  String get idString => id?.toString() ?? '';

  /// The first non-empty of the product/project/execution name candidates.
  String get scopeName =>
      (productName ??
              projectName ??
              executionName ??
              product ??
              project ??
              execution ??
              '')
          .toString();
}

/// One `{ total, <bugs|tasks|stories>: [...] }` group inside the `GET /user`
/// (assigned-to-me) response. The list key varies by kind, so this reads the
/// first list value in the group rather than a fixed key.
class ZenTaoAssignedGroup {
  const ZenTaoAssignedGroup({required this.total, required this.items});
  final int total;
  final List<ZenTaoEntity> items;

  factory ZenTaoAssignedGroup.fromJson(Map<String, dynamic> json) {
    final lists = json.values.whereType<List>();
    final list = lists.isEmpty ? const [] : lists.first;
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
