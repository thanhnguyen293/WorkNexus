import 'package:json_annotation/json_annotation.dart';

part 'gitlab_models.g.dart';

// ─────────────────────────────────────────────────────────────────────────────
// JSON DTOs for the GitLab REST v4 API (deserialize-only). Unlike ZenTao, GitLab
// returns clean, well-typed JSON, so these use strongly-typed fields with
// `fieldRename: FieldRename.snake` (maps `path_with_namespace` ↔ pathWithNamespace,
// `web_url` ↔ webUrl, `project_id` ↔ projectId, …). List endpoints return a bare
// JSON array (parsed in `gitlab_client.dart`); pagination lives in the
// `X-Next-Page` response header. These DTOs never leave the data layer (rule
// 3.3): `gitlab_normalize.dart` maps them to domain entities at the boundary.
// ─────────────────────────────────────────────────────────────────────────────

/// A GitLab user — the `GET /user` result and the `author`/`assignee`/`reviewer`
/// objects embedded in issues and merge requests.
@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class GitLabUser {
  const GitLabUser({this.id, this.username, this.name});

  final int? id;
  final String? username;
  final String? name;

  factory GitLabUser.fromJson(Map<String, dynamic> json) =>
      _$GitLabUserFromJson(json);

  /// Human-friendly display name, falling back to the username.
  String get display =>
      (name != null && name!.isNotEmpty) ? name! : (username ?? '');
}

/// A GitLab project from `GET /projects` — the container the sidebar browses and
/// that scopes issue/MR fetches (parallel to a ZenTao product).
@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class GitLabProject {
  const GitLabProject({
    required this.id,
    this.name,
    this.pathWithNamespace,
    this.nameWithNamespace,
    this.webUrl,
  });

  final int id;
  final String? name;
  final String? pathWithNamespace;
  final String? nameWithNamespace;
  final String? webUrl;

  factory GitLabProject.fromJson(Map<String, dynamic> json) =>
      _$GitLabProjectFromJson(json);

  /// Display name — the namespaced name if present (e.g. `Group / Web`).
  String get display =>
      (nameWithNamespace != null && nameWithNamespace!.isNotEmpty)
      ? nameWithNamespace!
      : (name ?? pathWithNamespace ?? '$id');
}

/// A GitLab issue from `GET /issues` or `GET /projects/:id/issues`.
@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class GitLabIssue {
  const GitLabIssue({
    required this.id,
    required this.iid,
    required this.projectId,
    this.title,
    this.description,
    this.state,
    this.labels = const [],
    this.author,
    this.assignees = const [],
    this.webUrl,
    this.references,
    this.upvotes,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int iid;
  final int projectId;
  final String? title;
  final String? description;
  final String? state; // opened | closed
  @JsonKey(defaultValue: <String>[])
  final List<String> labels;
  final GitLabUser? author;
  @JsonKey(defaultValue: <GitLabUser>[])
  final List<GitLabUser> assignees;
  final String? webUrl;
  final GitLabReferences? references;
  final int? upvotes;
  final String? createdAt;
  final String? updatedAt;

  factory GitLabIssue.fromJson(Map<String, dynamic> json) =>
      _$GitLabIssueFromJson(json);
}

/// A GitLab merge request from `GET /merge_requests` or
/// `GET /projects/:id/merge_requests`.
@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class GitLabMergeRequest {
  const GitLabMergeRequest({
    required this.id,
    required this.iid,
    required this.projectId,
    this.title,
    this.description,
    this.state,
    this.draft = false,
    this.labels = const [],
    this.author,
    this.assignees = const [],
    this.reviewers = const [],
    this.sourceBranch,
    this.targetBranch,
    this.mergeStatus,
    this.detailedMergeStatus,
    this.webUrl,
    this.references,
    this.upvotes,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int iid;
  final int projectId;
  final String? title;
  final String? description;
  final String? state; // opened | closed | merged | locked
  @JsonKey(defaultValue: false)
  final bool draft;
  @JsonKey(defaultValue: <String>[])
  final List<String> labels;
  final GitLabUser? author;
  @JsonKey(defaultValue: <GitLabUser>[])
  final List<GitLabUser> assignees;
  @JsonKey(defaultValue: <GitLabUser>[])
  final List<GitLabUser> reviewers;
  final String? sourceBranch;
  final String? targetBranch;
  final String? mergeStatus;
  final String? detailedMergeStatus;
  final String? webUrl;
  final GitLabReferences? references;
  final int? upvotes;
  final String? createdAt;
  final String? updatedAt;

  factory GitLabMergeRequest.fromJson(Map<String, dynamic> json) =>
      _$GitLabMergeRequestFromJson(json);
}

/// The `references` block on an issue/MR (`{ short, relative, full }`), used to
/// render a human key like `group/web!42`.
@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class GitLabReferences {
  const GitLabReferences({this.short, this.relative, this.full});

  final String? short;
  final String? relative;
  final String? full;

  factory GitLabReferences.fromJson(Map<String, dynamic> json) =>
      _$GitLabReferencesFromJson(json);
}

/// A note (comment or system event) from `.../notes`. `system == true` marks an
/// auto-generated activity note (assigned, closed, …) rather than a user comment.
@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class GitLabNote {
  const GitLabNote({
    required this.id,
    this.body,
    this.author,
    this.system = false,
    this.createdAt,
  });

  final int id;
  final String? body;
  final GitLabUser? author;
  @JsonKey(defaultValue: false)
  final bool system;
  final String? createdAt;

  factory GitLabNote.fromJson(Map<String, dynamic> json) =>
      _$GitLabNoteFromJson(json);
}
