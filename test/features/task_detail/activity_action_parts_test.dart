import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/task_detail/presentation/util/activity_action_parts.dart';

void main() {
  test('highlights the person an assignment names', () {
    expect(activityActionParts('assigned to JunNg-VN-Flutter'), [
      ('assigned to ', ActivityPartKind.plain),
      ('JunNg-VN-Flutter', ActivityPartKind.user),
    ]);
  });

  test('sets a changed field value apart', () {
    expect(activityActionParts('resolved · resolution: Fixed'), [
      ('resolved · resolution: ', ActivityPartKind.plain),
      ('Fixed', ActivityPartKind.value),
    ]);
  });

  test('leaves a plain phrase as one run', () {
    expect(activityActionParts('confirmed the bug'), [
      ('confirmed the bug', ActivityPartKind.plain),
    ]);
  });

  test('reads the event kind from the leading verb', () {
    expect(activityKindOf('created'), ActivityKind.created);
    expect(activityKindOf('assigned to Thanh'), ActivityKind.assigned);
    expect(
      activityKindOf('resolved · resolution: Fixed'),
      ActivityKind.resolved,
    );
    expect(activityKindOf('activated'), ActivityKind.reopened);
    expect(activityKindOf('confirmed the bug'), ActivityKind.confirmed);
    expect(activityKindOf('closed (done)'), ActivityKind.closed);
    expect(activityKindOf('linked a commit'), ActivityKind.other);
  });
}
