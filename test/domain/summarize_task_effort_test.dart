import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/provider_entity.dart';
import 'package:work_nexus/tools/zentao/domain/usecases/summarize_task_effort.dart';

void main() {
  const summarize = SummarizeTaskEffort();

  ZenTaoTaskEntity task({double? estimate, double? consumed, double? left}) =>
      ZenTaoTaskEntity(estimate: estimate, consumed: consumed, left: left);

  test('a task with no hours on record has no effort', () {
    expect(summarize(task()), isNull);
    expect(summarize(task(estimate: 0, consumed: 0, left: 0)), isNull);
  });

  test('progress is logged over logged plus left', () {
    final effort = summarize(task(estimate: 8, consumed: 6, left: 2));
    expect(effort?.progress, 0.75);
    expect(effort?.estimate, 8);
  });

  test('work beyond the estimate still reads from the hours left', () {
    final effort = summarize(task(estimate: 4, consumed: 6, left: 2));
    expect(effort?.progress, 0.75);
  });

  test('an estimate with nothing logged has not started', () {
    expect(summarize(task(estimate: 5))?.progress, 0);
  });

  test('negative or missing hours count as none', () {
    final effort = summarize(task(consumed: -3, left: 4));
    expect(effort?.consumed, 0);
    expect(effort?.progress, 0);
  });
}
