import 'dart:io';

import 'package:crypto/crypto.dart';

/// Certificate details captured when the TLS handshake rejects a certificate.
final class XxdCertificate {
  const XxdCertificate({
    required this.host,
    required this.fingerprint,
    required this.subject,
    required this.issuer,
  });

  factory XxdCertificate.of(X509Certificate cert, String host) =>
      XxdCertificate(
        host: host,
        fingerprint: certificateFingerprint(cert.der),
        subject: cert.subject,
        issuer: cert.issuer,
      );

  final String host;
  final String fingerprint;
  final String subject;
  final String issuer;
}

/// SHA-256 of a DER certificate as `AB:CD:…`, the form browsers display.
String certificateFingerprint(List<int> der) => sha256
    .convert(der)
    .bytes
    .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
    .join(':');

String _normalize(String fingerprint) =>
    fingerprint.replaceAll(':', '').toUpperCase();

/// Builds an [HttpClient] for xxd. xxd ships a self-signed certificate, so a
/// certificate the system rejects is accepted only when its fingerprint equals
/// [pinnedFingerprint] (trust-on-first-use). Otherwise the rejected
/// certificate is reported to [onRejected] so the caller can ask the user.
HttpClient createPinnedHttpClient({
  String? pinnedFingerprint,
  void Function(XxdCertificate cert)? onRejected,
}) {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  client.badCertificateCallback = (cert, host, port) {
    final seen = XxdCertificate.of(cert, host);
    final pin = pinnedFingerprint;
    if (pin != null && _normalize(pin) == _normalize(seen.fingerprint)) {
      return true;
    }
    onRejected?.call(seen);
    return false;
  };
  return client;
}
