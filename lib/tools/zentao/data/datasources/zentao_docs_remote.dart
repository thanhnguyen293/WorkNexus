import 'dart:typed_data';

import 'zentao_client.dart';

/// The ZenTao REST v1 document endpoints. Only REST v1 is used: on ZenTao
/// 21.x the classic `doc-*.json` pages are rendered client-side and carry no
/// document data.
class ZenTaoDocsRemote {
  const ZenTaoDocsRemote(this._client);

  final ZenTaoClient _client;

  String get baseUrl => _client.baseUrl;

  Future<Map<String, dynamic>> libs() => _client.getV1Json('/doclibs');

  Future<Map<String, dynamic>> docs(String libId) =>
      _client.getV1Json('/docs', query: {'lib': libId});

  Future<Map<String, dynamic>> doc(String docId) =>
      _client.getV1Json('/docs/$docId');

  Future<Uint8List?> image(String url) => _client.fetchBytes(url);

  Future<Uint8List?> download(String url) => _client.downloadBytes(url);
}
