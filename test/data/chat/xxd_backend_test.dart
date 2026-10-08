import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/chat/data/datasources/xxd/xxd_backend.dart';
import 'package:work_nexus/features/chat/data/datasources/xxd/xxd_server_info.dart';

XxdServerInfo _info({String requestType = 'PATH_INFO'}) => XxdServerInfo(
  token: 't',
  chatPort: 11444,
  version: '',
  enableClientAes: false,
  backendUrl: 'https://zt.example.com/',
  authToken: 'tok',
  requestType: requestType,
);

void main() {
  group('authorizeUri', () {
    test('PATH_INFO joins action params with "_"', () {
      final uri = XxdBackend.authorizeUri(
        _info(),
        'thanh',
        module: 'user',
        method: 'cropAvatar',
        params: {'imageID': '42'},
      );
      expect(
        '$uri',
        'https://zt.example.com/im-authorize-thanh-tok60ae136e5d49fbdf037fab5f1d805634-desktop-'
            'user_cropAvatar_42.html.html',
      );
    });

    test('derives the key from a 64-char authToken and the time slot, '
        'like the official client', () {
      const info = XxdServerInfo(
        token: 't',
        chatPort: 11444,
        version: '',
        enableClientAes: false,
        backendUrl: 'https://zt.example.com/',
        authToken:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      );
      final uri = XxdBackend.authorizeUri(
        info,
        'thanh',
        module: 'file',
        method: 'uploadChatAvatar',
        now: DateTime.fromMillisecondsSinceEpoch(1760000000000),
      );
      expect(
        '$uri',
        'https://zt.example.com/im-authorize-thanh-'
            'b0de6f721aa411f9f2bf70c91bb878075cbfc835197a6fcc2b935020eb72e89b-desktop-'
            'file_uploadChatAvatar.html.html',
      );
    });

    test('GET mode passes action params by name', () {
      final uri = XxdBackend.authorizeUri(
        _info(requestType: 'GET'),
        'thanh',
        module: 'user',
        method: 'cropAvatar',
        params: {'imageID': '42'},
      );
      expect(
        uri?.queryParameters['url'],
        'index.php?m=user&f=cropAvatar&imageID=42',
      );
    });
  });

  group('userAvatarFileId', () {
    test('reads fileID when present', () {
      expect(
        XxdBackend.userAvatarFileId('{"result":"success","fileID":7}'),
        '7',
      );
    });

    test('reads the id from a ZenTao 18+ crop callback', () {
      expect(
        XxdBackend.userAvatarFileId(
          jsonEncode({
            'result': 'success',
            'callback': "loadModal('/user-cropavatar-123.html', 'profile');",
          }),
        ),
        '123',
      );
    });

    test('reads the id from a GET-style locate', () {
      expect(
        XxdBackend.userAvatarFileId(
          jsonEncode({
            'result': 'success',
            'locate': '/index.php?m=user&f=cropavatar&image=55',
          }),
        ),
        '55',
      );
    });

    test('is null for a failed upload', () {
      expect(
        XxdBackend.userAvatarFileId(
          '{"result":"fail","message":"cropavatar 9"}',
        ),
        isNull,
      );
    });
  });

  test('follows im-authorize 307 and re-sends the upload', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    String? uploaded;
    server.listen((request) async {
      final body = await utf8.decoder.bind(request).join();
      if (request.uri.path == '/im-authorize.html') {
        request.response
          ..statusCode = HttpStatus.temporaryRedirect
          ..headers.set(
            HttpHeaders.locationHeader,
            'my-uploadAvatar.json?zentaosid=s',
          );
      } else {
        uploaded = body;
        request.response.write(
          jsonEncode({
            'result': 'success',
            'callback': "loadModal('/user-cropavatar-9.html');",
          }),
        );
      }
      await request.response.close();
    });

    final id = await const XxdBackend().uploadUserAvatar(
      Uri.parse('http://127.0.0.1:${server.port}/im-authorize.html'),
      Uint8List.fromList([1, 2, 3]),
    );

    expect(id, isA<Ok<String>>().having((r) => r.value, 'value', '9'));
    // ZenTao reads the picture from `files` (saveUpload's default field).
    expect(uploaded, contains('name="files"'));
  });

  test('carries the session cookie im-authorize sets to the upload', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    String? cookieOnUpload;
    server.listen((request) async {
      await request.drain<void>();
      if (request.uri.path == '/im-authorize.html') {
        request.response
          ..statusCode = HttpStatus.temporaryRedirect
          ..cookies.add(Cookie('zentaosid', 'signed-in'))
          ..headers.set(
            HttpHeaders.locationHeader,
            'file-uploadChatAvatar.json',
          );
      } else {
        cookieOnUpload = request.headers.value(HttpHeaders.cookieHeader);
        request.response.write(jsonEncode({'id': 77}));
      }
      await request.response.close();
    });

    final id = await const XxdBackend().uploadChatAvatar(
      Uri.parse('http://127.0.0.1:${server.port}/im-authorize.html'),
      Uint8List.fromList([1, 2, 3]),
    );

    expect(id, isA<Ok<String>>().having((r) => r.value, 'value', '77'));
    expect(cookieOnUpload, contains('zentaosid=signed-in'));
  });
}
