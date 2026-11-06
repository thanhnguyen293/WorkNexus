import '../../error/result.dart';

/// Certificates the user accepted for servers the system does not trust, such
/// as a ZenTao chat server's self-signed one: each by its SHA-256 fingerprint,
/// upper-case hex without separators. Owned by the chat, which pins them;
/// read by the mini apps, whose pages call the same servers.
abstract interface class PinnedCertificateRepository {
  Future<Result<Set<String>>> fingerprints();
}
