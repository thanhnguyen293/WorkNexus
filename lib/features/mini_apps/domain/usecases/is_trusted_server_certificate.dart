import '../../../../core/domain/repositories/pinned_certificate_repository.dart';
import '../../../../core/error/result.dart';
import '../entities/trusted_certificate.dart';
import '../repositories/trusted_certificate_repository.dart';
import '../value_objects/certificate_fingerprint.dart';

/// Whether a certificate the system refuses, met at [host], is one the user
/// already accepted: pinned by the app's chat for its server, or trusted for
/// that host in a mini app (from any of its ports, as ZenTao's chat server
/// answers on two). Only that very certificate, never another one.
class IsTrustedServerCertificate {
  const IsTrustedServerCertificate(this._pins, this._trusted);

  final PinnedCertificateRepository _pins;
  final TrustedCertificateRepository _trusted;

  Future<bool> call({required String host, required List<int> der}) async {
    if (der.isEmpty) return false;
    final seen = certificateFingerprint(der);
    // Anything unreadable trusts nothing: the system's answer stands.
    final pins = switch (await _pins.fingerprints()) {
      Ok(:final value) => value,
      Err() => const <String>{},
    };
    if (pins.contains(seen)) return true;
    final trusted = switch (await _trusted.all()) {
      Ok(:final value) => value,
      Err() => const <TrustedCertificate>[],
    };
    return trusted.any((t) => t.fingerprint == seen && t.host == host);
  }
}
