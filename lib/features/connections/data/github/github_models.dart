import 'package:json_annotation/json_annotation.dart';

part 'github_models.g.dart';

// ─────────────────────────────────────────────────────────────────────────────
// JSON DTOs for the GitHub REST API (deserialize-only). GitHub returns clean,
// well-typed JSON, so these use strongly-typed fields with
// `fieldRename: FieldRename.snake` (maps `html_url` ↔ htmlUrl, `full_name` ↔
// fullName, `created_at` ↔ createdAt, …). List endpoints return a bare JSON
// array; the Search API wraps results in `{ items: [...] }`. Pagination lives in
// the RFC-5988 `Link` response header (parsed in `github_client.dart`). These
// DTOs never leave the data layer (rule 3.3): `github_normalize.dart` maps them
// to domain entities at the boundary.
//
// GitHub-specific shape vs GitLab: a PR *is* a kind of issue — the `/issues` and
// search endpoints return PRs too, tagged with a `pull_request` object; the
// `/pulls` endpoint carries the richer PR fields (draft, branches, merge state).
// ─────────────────────────────────────────────────────────────────────────────

/// A GitHub user — the `GET /user` result and the `user`/`assignee`/reviewer
/// objects embedded in issues and pull requests. Assignment uses [login]
/// directly (GitHub takes login strings, not the numeric ids GitLab needs).
@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class GitHubUser {
  const GitHubUser({this.login, this.name});

  final String? login;
  final String? name;

  factory GitHubUser.fromJson(Map<String, dynamic> json) =>
      _$GitHubUserFromJson(json);

  /// Human-friendly display name, falling back to the login.
  String get display =>
      (name != null && name!.isNotEmpty) ? name! : (login ?? '');
}

/// A repository from `GET /user/repos` — the container the sidebar browses and
/// that scopes issue/PR fetches (parallel to a ZenTao product / GitLab project).
@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class GitHubRepo {
  const GitHubRepo({required this.fullName, this.name, this.htmlUrl});

  /// `owner/name` — GitHub's canonical repository reference used in every
  /// `/repos/:owner/:repo/…` path.
  final String fullName;
  final String? name;
  final String? htmlUrl;

  factory GitHubRepo.fromJson(Map<String, dynamic> json) =>
      _$GitHubRepoFromJson(json);

  String get display => fullName;
}

/// A label object `{ name, color }`. Unlike GitLab (bare strings), GitHub labels
/// are objects; the normalizer projects them to their names.
@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class GitHubLabel {
  const GitHubLabel({this.name});

  final String? name;

  factory GitHubLabel.fromJson(Map<String, dynamic> json) =>
      _$GitHubLabelFromJson(json);
}

/// The `pull_request` marker embedded in an issue-shaped object (search results
/// and `/issues`). Its presence marks the item as a PR; [mergedAt] distinguishes
/// a merged PR from a plain closed one.
@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class GitHubPullMarker {
  const GitHubPullMarker({this.mergedAt, this.htmlUrl});

  final String? mergedAt;
  final String? htmlUrl;

  factory GitHubPullMarker.fromJson(Map<String, dynamic> json) =>
      _$GitHubPullMarkerFromJson(json);
}

/// An issue-shaped object from the Search API (`/search/issues`) or
/// `GET /repos/:owner/:repo/issues`. Carries both plain issues and PRs (a PR has
/// a non-null [pullRequest]); [repositoryUrl] identifies the owning repo when the
/// fetch wasn't already repo-scoped (i.e. from the global search feed).
@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class GitHubIssue {
  const GitHubIssue({
    required this.number,
    this.title,
    this.body,
    this.state,
    this.draft,
    this.labels = const [],
    this.user,
    this.assignees = const [],
    this.htmlUrl,
    this.repositoryUrl,
    this.pullRequest,
    this.comments,
    this.createdAt,
    this.updatedAt,
  });

  final int number;
  final String? title;
  final String? body;
  final String? state; // open | closed
  final bool? draft;
  @JsonKey(defaultValue: <GitHubLabel>[])
  final List<GitHubLabel> labels;
  final GitHubUser? user;
  @JsonKey(defaultValue: <GitHubUser>[])
  final List<GitHubUser> assignees;
  final String? htmlUrl;
  final String? repositoryUrl;
  final GitHubPullMarker? pullRequest;
  final int? comments;
  final String? createdAt;
  final String? updatedAt;

  /// A PR is an issue with a `pull_request` block.
  bool get isPullRequest => pullRequest != null;

  factory GitHubIssue.fromJson(Map<String, dynamic> json) =>
      _$GitHubIssueFromJson(json);
}

/// A branch ref on a pull request (`head`/`base`), carrying the branch name and
/// (for `base`) the owning repository.
@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class GitHubRef {
  const GitHubRef({this.ref, this.repo});

  final String? ref;
  final GitHubRepo? repo;

  factory GitHubRef.fromJson(Map<String, dynamic> json) =>
      _$GitHubRefFromJson(json);
}

/// A pull request from `GET /repos/:owner/:repo/pulls` or `/pulls/:number` — the
/// richer PR view (draft, branches, merge status, reviewers) the issue shape
/// lacks.
@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class GitHubPull {
  const GitHubPull({
    required this.number,
    this.title,
    this.body,
    this.state,
    this.draft = false,
    this.merged,
    this.mergedAt,
    this.mergeableState,
    this.labels = const [],
    this.user,
    this.assignees = const [],
    this.requestedReviewers = const [],
    this.head,
    this.base,
    this.htmlUrl,
    this.comments,
    this.createdAt,
    this.updatedAt,
  });

  final int number;
  final String? title;
  final String? body;
  final String? state; // open | closed
  @JsonKey(defaultValue: false)
  final bool draft;
  final bool? merged;
  final String? mergedAt;
  final String? mergeableState;
  @JsonKey(defaultValue: <GitHubLabel>[])
  final List<GitHubLabel> labels;
  final GitHubUser? user;
  @JsonKey(defaultValue: <GitHubUser>[])
  final List<GitHubUser> assignees;
  @JsonKey(defaultValue: <GitHubUser>[])
  final List<GitHubUser> requestedReviewers;
  final GitHubRef? head;
  final GitHubRef? base;
  final String? htmlUrl;
  final int? comments;
  final String? createdAt;
  final String? updatedAt;

  /// A PR is "merged" when the flag is set or a merge timestamp is present
  /// (`state` alone stays `closed` for both merged and abandoned PRs).
  bool get isMerged =>
      merged == true || (mergedAt != null && mergedAt!.isNotEmpty);

  factory GitHubPull.fromJson(Map<String, dynamic> json) =>
      _$GitHubPullFromJson(json);
}

/// A comment from `.../issues/:number/comments` (the same endpoint serves issues
/// and PRs).
@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class GitHubComment {
  const GitHubComment({required this.id, this.body, this.user, this.createdAt});

  final int id;
  final String? body;
  final GitHubUser? user;
  final String? createdAt;

  factory GitHubComment.fromJson(Map<String, dynamic> json) =>
      _$GitHubCommentFromJson(json);
}

/// An event from `.../issues/:number/events` — the activity timeline (assigned,
/// labeled, closed, reopened, merged, …). [event] is the verb.
@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class GitHubEvent {
  const GitHubEvent({required this.id, this.event, this.actor, this.createdAt});

  final int id;
  final String? event;
  final GitHubUser? actor;
  final String? createdAt;

  factory GitHubEvent.fromJson(Map<String, dynamic> json) =>
      _$GitHubEventFromJson(json);
}
