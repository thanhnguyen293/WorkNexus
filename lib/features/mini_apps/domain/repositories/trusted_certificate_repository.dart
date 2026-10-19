import '../entities/trusted_certificate.dart';

/// The sites whose invalid certificate the user chose to accept, one entry per
/// site.
abstract class TrustedCertificateRepository {
  Future<List<TrustedCertificate>> all();

  /// Whether the user trusted [origin]'s certificate, for whatever problem.
  Future<bool> isOriginTrusted(String origin);

  /// Trusts [origin], which was refused with [error]; a site already trusted
  /// keeps one entry, with the latest error.
  Future<void> trust(String origin, String error);

  Future<void> forget(TrustedCertificate certificate);

  Future<void> forgetAll();
}
