import 'package:crypto/crypto.dart';

/// A certificate's SHA-256 fingerprint from its DER bytes: upper-case hex
/// without separators, as pins are compared.
String certificateFingerprint(List<int> der) =>
    sha256.convert(der).toString().toUpperCase();
