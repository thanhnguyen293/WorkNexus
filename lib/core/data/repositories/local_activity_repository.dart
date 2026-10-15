import 'package:drift/drift.dart';

import '../../database/database.dart';
import '../../domain/entities/activity_event.dart';
import '../../domain/repositories/activity_repository.dart';
import '../mappers/mappers.dart';

/// Drift-backed activity history (populated from the provider on detail sync),
/// replacing the demo [FixtureActivityRepository] which fabricated events.
class LocalActivityRepository implements ActivityRepository {
  LocalActivityRepository(this._db);
  final AppDatabase _db;

  @override
  Stream<List<ActivityEvent>> watchActivity(String ticketId) => _db
      .watchActivity(ticketId)
      .map((rows) => rows.map(activityFromRow).toList());

  @override
  Future<void> upsertActivity(List<ActivityEvent> events) async {
    if (events.isEmpty) return;
    await _db.batch((b) {
      for (final e in events) {
        b.insert(
          _db.activities,
          activityToCompanion(e),
          onConflict: DoUpdate((_) => activityToCompanion(e)),
        );
      }
    });
  }
}
