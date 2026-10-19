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
  const factory TrustedCertificate({
    required String origin,
    required String error,
  }) = _TrustedCertificate;
}
