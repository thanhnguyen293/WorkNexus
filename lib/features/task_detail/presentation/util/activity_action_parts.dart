/// How a run of an activity phrase is emphasized in the timeline.
enum ActivityPartKind { plain, user, value }

/// Splits an activity phrase (as the adapters word it, e.g. "assigned to
/// Thanh", "resolved · resolution: Fixed") into runs, so the person it names
/// reads like the actor and a field's new value stands out.
List<(String, ActivityPartKind)> activityActionParts(String action) {
  final assigned = RegExp(r'^(assigned to )(.+)$').firstMatch(action);
  if (assigned != null) {
    return [
      (assigned.group(1)!, ActivityPartKind.plain),
      (assigned.group(2)!, ActivityPartKind.user),
    ];
  }
  final field = RegExp(r'^(.*?: )(.+)$').firstMatch(action);
  if (field != null) {
    return [
      (field.group(1)!, ActivityPartKind.plain),
      (field.group(2)!, ActivityPartKind.value),
    ];
  }
  return [(action, ActivityPartKind.plain)];
}

/// What an activity event did, read from its phrase's leading verb — picks the
/// event's icon in the timeline.
enum ActivityKind {
  created,
  assigned,
  edited,
  resolved,
  reopened,
  confirmed,
  closed,
  other,
}

ActivityKind activityKindOf(String action) {
  final verb = action.trim().split(RegExp(r'[\s·(]')).first.toLowerCase();
  return switch (verb) {
    'created' || 'opened' => ActivityKind.created,
    'assigned' || 'unassigned' => ActivityKind.assigned,
    'edited' || 'updated' || 'changed' => ActivityKind.edited,
    'resolved' || 'merged' => ActivityKind.resolved,
    'activated' || 'reopened' => ActivityKind.reopened,
    'confirmed' => ActivityKind.confirmed,
    'closed' => ActivityKind.closed,
    _ => ActivityKind.other,
  };
}
