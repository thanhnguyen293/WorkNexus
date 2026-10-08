import '../../../../core/error/result.dart';
import '../repositories/chat_repository.dart';

/// Trusts the chat server certificate the user confirmed, then reconnects.
class TrustChatCertificate {
  const TrustChatCertificate(this._repository);

  final ChatRepository _repository;

  Future<Result<void>> call({
    required String accountId,
    required String fingerprint,
  }) => _repository.trustCertificate(accountId, fingerprint);
}
