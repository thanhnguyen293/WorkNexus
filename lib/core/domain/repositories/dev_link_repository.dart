import '../entities/dev_link.dart';

/// Code artifacts (repo/branch/commit/PR) linked to a ticket.
abstract class DevLinkRepository {
  Stream<List<DevLink>> watchDevLinks(String ticketId);
  Future<void> upsertDevLinks(List<DevLink> links);
}
