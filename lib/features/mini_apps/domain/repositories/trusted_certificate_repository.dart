import '../../../../core/error/result.dart';
import '../entities/trusted_certificate.dart';

/// The sites whose invalid certificate the user chose to accept, one entry per
/// site. Each change answers with the list as it now is.
abstract class TrustedCertificateRepository {
  Future<Result<List<TrustedCertificate>>> all();

  /// Trusts [origin], which was refused with [error]; a site already trusted
  /// keeps one entry, with the latest error.
  Future<Result<List<TrustedCertificate>>> trust(String origin, String error);

  Future<Result<List<TrustedCertificate>>> forget(
    TrustedCertificate certificate,
  );

  Future<Result<List<TrustedCertificate>>> forgetAll();
}
