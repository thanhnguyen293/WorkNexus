import '../../../core/domain/entities/dev_link.dart';
import '../../../core/domain/repositories/dev_link_repository.dart';

/// Real dev-link source — empty until repo/branch/PR linking is implemented.
class EmptyDevLinkRepository implements DevLinkRepository {
  const EmptyDevLinkRepository();

  @override
  Stream<List<DevLink>> watchDevLinks(String ticketId) =>
      Stream.value(const []);

  @override
  Future<void> upsertDevLinks(List<DevLink> links) async {}
}
