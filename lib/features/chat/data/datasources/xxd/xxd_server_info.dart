/// Login parameters for one xxd account.
final class XxdCredentials {
  const XxdCredentials({
    required this.server,
    required this.account,
    required this.password,
    this.serverName = '',
    this.pinnedFingerprint,
  });

  /// xxd HTTPS origin, e.g. `https://zentao.example.com:11443`.
  final Uri server;
  final String account;
  final String password;

  /// Empty for the default server configured in xxd.
  final String serverName;

  /// Trusted SHA-256 certificate fingerprint for a self-signed xxd.
  final String? pinnedFingerprint;
}

/// The `sysgetserverinfo` reply: session token and how to reach the socket.
final class XxdServerInfo {
  const XxdServerInfo({
    required this.token,
    required this.chatPort,
    required this.version,
    required this.enableClientAes,
    this.socketUrl,
    this.apiScheme,
    this.uploadFileSize,
    this.backendUrl,
    this.authToken,
    this.requestType = 'PATH_INFO',
    this.requestFix = '-',
  });

  /// Returns null when the reply carries no token (login rejected).
  static XxdServerInfo? tryParse(Map<String, Object?> json) {
    final token = json['token'];
    if (token is! String || token.isEmpty) return null;
    final socketUrl = json['socketUrl'];
    final scheme = json['apiScheme'];
    return XxdServerInfo(
      token: token,
      chatPort: _int(json['chatPort']) ?? 11444,
      version: '${json['version'] ?? ''}',
      enableClientAes: _truthy(json['enableClientAES']),
      socketUrl: socketUrl is String && socketUrl.isNotEmpty ? socketUrl : null,
      apiScheme: scheme is Map ? Map<String, Object?>.from(scheme) : null,
      uploadFileSize: _int(json['uploadFileSize']),
      backendUrl: json['backendURL'] as String?,
      authToken: json['authToken'] as String?,
      requestType: '${json['requestType'] ?? 'PATH_INFO'}',
      requestFix: '${json['requestFix'] ?? '-'}',
    );
  }

  final String token;
  final int chatPort;
  final String version;
  final bool enableClientAes;
  final String? socketUrl;
  final Map<String, Object?>? apiScheme;
  final int? uploadFileSize;
  final String? backendUrl;

  /// Short-lived key for ZenTao web calls through `im-authorize`.
  final String? authToken;

  /// ZenTao URL style: `PATH_INFO` (`module-method-args.html`) or `GET`
  /// (`index.php?m=&f=`), and the PATH_INFO separator.
  final String requestType;
  final String requestFix;

  /// `socketUrl` when given, else `wss://<host>:<chatPort>/ws`.
  Uri socketUri(Uri server) => switch (socketUrl) {
    final url? => Uri.parse(url),
    null => Uri(
      scheme: server.scheme == 'https' ? 'wss' : 'ws',
      host: server.host,
      port: chatPort,
      path: '/ws',
    ),
  };

  static int? _int(Object? v) =>
      v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);

  static bool _truthy(Object? v) =>
      v == true || (v is num && v != 0) || v == '1' || v == 'true';
}
