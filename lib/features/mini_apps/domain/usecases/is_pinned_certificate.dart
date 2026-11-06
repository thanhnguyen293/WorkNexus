import 'package:crypto/crypto.dart';

import '../../../../core/domain/repositories/pinned_certificate_repository.dart';
import '../../../../core/error/result.dart';

/// Whether a server's certificate, given as DER bytes, is one the user already
/// accepted elsewhere in the app (the chat pins its server's self-signed
/// certificate). A mini app's page that calls that server is let through only
/// for that very certificate, never for any other the system refuses.
class IsPinnedCertificate {
  const IsPinnedCertificate(this._pins);

  final PinnedCertificateRepository _pins;

  Future<bool> call(List<int> der) async {
    if (der.isEmpty) return false;
    final pins = switch (await _pins.fingerprints()) {
      Ok(:final value) => value,
      // Unreadable pins trust nothing: the system's answer stands.
      Err() => const <String>{},
    };
    if (pins.isEmpty) return false;
    final seen = sha256
        .convert(der)
        .bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
    return pins.contains(seen);
  }
}
