import 'package:freezed_annotation/freezed_annotation.dart';

part 'trusted_certificate.freezed.dart';

/// A site whose invalid certificate the user chose to trust: the [origin]
/// (`https://host:port`) and the [error] its certificate was refused with when
/// they trusted it (`net::ERR_CERT_DATE_INVALID`), kept to say in Settings what
/// was accepted. Trust is for the site: while its page is shown the web view
/// ignores certificate errors, whatever they are, so a certificate that fails
/// some other way is accepted too. Forget the site to be asked again.
@freezed
abstract class TrustedCertificate with _$TrustedCertificate {
  const TrustedCertificate._();

  const factory TrustedCertificate({
    required String origin,
    required String error,

    /// The SHA-256 of the certificate the user accepted (upper-case hex, no
    /// separators), where the web view says which one it met (macOS). Then
    /// only that certificate is accepted, from any port of the same host, as
    /// a server such as ZenTao's chat serves it on more than one. Null where
    /// trust is for the site, whatever its certificate (Windows).
    String? fingerprint,
  }) = _TrustedCertificate;

  /// The host of [origin], `zentao.example.com` of
  /// `https://zentao.example.com:11443`.
  String get host => Uri.tryParse(origin)?.host ?? '';
}
