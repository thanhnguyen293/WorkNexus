/// What one read of an execution's bug list (sorted by task, highest first)
/// covered, so opening another task of the execution soon after reads
/// nothing again: the whole list ([complete]), the bugs of every task above
/// [above], and in any case those of the [tasks] it was read for.
class TaskBugsCoverage {
  const TaskBugsCoverage({
    required this.at,
    this.complete = false,
    this.above,
    this.tasks = const {},
  });

  /// How long a read stays good: bugs filed or relinked meanwhile show on
  /// the next read after it.
  static const ttl = Duration(minutes: 5);

  final DateTime at;
  final bool complete;
  final int? above;
  final Set<int> tasks;

  /// Whether this read, still fresh at [now], holds every bug of [task].
  bool covers(int task, DateTime now) {
    if (now.difference(at) >= ttl) return false;
    return complete ||
        tasks.contains(task) ||
        switch (above) {
          final above? => task > above,
          null => false,
        };
  }
}
