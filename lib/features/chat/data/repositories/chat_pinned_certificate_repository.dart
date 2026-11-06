import '../../../../core/domain/repositories/pinned_certificate_repository.dart';
import '../../../../core/error/guard_storage.dart';
import '../../../../core/error/result.dart';
import '../datasources/chat_local_datasource.dart';

/// The certificates pinned for the chat accounts' servers.
class ChatPinnedCertificateRepository implements PinnedCertificateRepository {
  const ChatPinnedCertificateRepository(this._local);

  final ChatLocalDatasource _local;

  @override
  Future<Result<Set<String>>> fingerprints() => guardStorage(
    'Could not read the pinned certificates',
    () async => {
      for (final pin in await _local.pinnedFingerprints())
        pin.replaceAll(':', '').toUpperCase(),
    },
  );
}
