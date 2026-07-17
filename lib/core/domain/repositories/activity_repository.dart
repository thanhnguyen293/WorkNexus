import '../entities/activity_event.dart';

/// Provider-side history timeline for a ticket.
abstract class ActivityRepository {
  Stream<List<ActivityEvent>> watchActivity(String ticketId);
  Future<void> upsertActivity(List<ActivityEvent> events);
}
