/// A request sent to xxd over the chat socket. The client identity fields
/// (`version`, `device`, `lang`) are added by `XxdFrameCodec`.
final class XxdRequest {
  const XxdRequest(
    this.method, {
    this.params,
    this.rid,
    this.userId,
    this.module,
  });

  final String method;
  final List<Object?>? params;
  final String? rid;
  final int? userId;

  /// Legacy module prefix; `im` (and null) means the default namespace.
  final String? module;

  /// Lower-cased `module/method`, also the prefix of the scheme name
  /// (`<apiName>Request`).
  String get apiName => _apiName(module, method);
}

/// A packet received from xxd: a reply to a request (matched by `rid` or
/// method) or a server push such as `messagesend`.
final class XxdResponse {
  const XxdResponse(this.raw);

  factory XxdResponse.fromJson(Object? json) {
    if (json is! Map) {
      throw FormatException('xxd packet is not an object: $json');
    }
    return XxdResponse(Map<String, Object?>.from(json));
  }

  final Map<String, Object?> raw;

  String get method => (raw['method'] as String?) ?? '';
  String? get module => raw['module'] as String?;
  String? get rid => raw['rid'] as String?;
  String? get result => raw['result'] as String?;
  String? get message => raw['message'] as String?;
  Object? get data => raw['data'];

  /// Lower-cased `module/method`, the key handlers are registered under.
  String get apiName => _apiName(module, method);

  /// Mirrors the client: a packet without a `result` field counts as success.
  bool get isSuccess => !raw.containsKey('result') || result == 'success';
}

String _apiName(String? module, String method) {
  final m = method.toLowerCase();
  return module != null && module.isNotEmpty && module != 'im'
      ? '${module.toLowerCase()}/$m'
      : m;
}
