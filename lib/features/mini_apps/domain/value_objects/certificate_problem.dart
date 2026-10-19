/// Why a site's certificate is refused, in the words the user is told.
enum CertificateProblem {
  /// Expired, or not valid yet.
  dates,

  /// Issued for another site name.
  name,

  /// Not issued by an authority the computer trusts (self-signed, say).
  authority,

  /// Revoked, weak, or refused for another reason.
  other;

  /// What a web view's error code (`net::ERR_CERT_DATE_INVALID`) says.
  static CertificateProblem of(String error) => switch (error) {
    'net::ERR_CERT_DATE_INVALID' => dates,
    'net::ERR_CERT_COMMON_NAME_INVALID' => name,
    'net::ERR_CERT_AUTHORITY_INVALID' => authority,
    _ => other,
  };

  /// Whether [error] is a refused certificate, as opposed to any other page
  /// error (offline, refused connection).
  static bool isCertificateError(String error) =>
      error.startsWith('net::ERR_CERT_');
}
