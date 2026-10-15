import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/tools/zentao/data/services/task_bugs_coverage.dart';

void main() {
  final at = DateTime(2026, 10, 14, 15);
  final soon = at.add(const Duration(minutes: 1));
  final late = at.add(TaskBugsCoverage.ttl);

  test('a sorted read covers the tasks above where it stopped', () {
    final read = TaskBugsCoverage(at: at, above: 11000, tasks: const {11548});

    expect(read.covers(11548, soon), isTrue);
    expect(read.covers(11001, soon), isTrue);
    expect(read.covers(11000, soon), isFalse);
    expect(read.covers(9000, soon), isFalse);
  });

  test('a complete read covers every task', () {
    expect(TaskBugsCoverage(at: at, complete: true).covers(1, soon), isTrue);
  });

  test('an unsorted read covers only the task it was for', () {
    final read = TaskBugsCoverage(at: at, tasks: const {8});

    expect(read.covers(8, soon), isTrue);
    expect(read.covers(9, soon), isFalse);
  });

  test('a read goes stale after a few minutes', () {
    expect(TaskBugsCoverage(at: at, complete: true).covers(1, late), isFalse);
  });
}
