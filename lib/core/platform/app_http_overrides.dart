import 'dart:io';

/// Allows connecting to self-hosted instances (ZenTao, GitLab, etc.) that use
/// self-signed or expired SSL certificates, particularly for loading media and avatars.
class AppHttpOverrides extends HttpOverrides {
  AppHttpOverrides();

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (cert, host, port) => true;
  }
}
