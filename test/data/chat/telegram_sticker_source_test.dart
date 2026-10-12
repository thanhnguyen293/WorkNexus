import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/features/chat/data/datasources/telegram_sticker_source.dart';
import 'package:work_nexus/features/chat/domain/entities/remote_sticker_set.dart';

/// Answers Bot API calls from [routes] (path → status and body).
class _FakeTelegram implements HttpClientAdapter {
  _FakeTelegram(this.routes);

  final Map<String, (int, Object)> routes;
  final paths = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.uri.path);
    final (status, body) =
        routes[options.uri.path] ?? (404, {'ok': false, 'description': 'x'});
    return body is List<int>
        ? ResponseBody.fromBytes(body, status)
        : ResponseBody.fromString(
            jsonEncode(body),
            status,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
  }

  @override
  void close({bool force = false}) {}
}

TelegramStickerSource _source(_FakeTelegram fake) =>
    TelegramStickerSource(dio: Dio()..httpClientAdapter = fake);

void main() {
  test('lists a set: stills, animations and videos with thumbnails', () async {
    final fake = _FakeTelegram({
      '/botT/getStickerSet': (
        200,
        {
          'ok': true,
          'result': {
            'name': 'Cats',
            'title': 'Cats!',
            'stickers': [
              {'file_id': 'a', 'emoji': '😺'},
              {
                'file_id': 'b',
                'is_animated': true,
                'thumbnail': {'file_id': 'bt'},
              },
              {
                'file_id': 'c',
                'is_video': true,
                'thumb': {'file_id': 'ct'},
              },
            ],
          },
        },
      ),
    });

    final res = await _source(fake).stickerSet('Cats', token: 'T');

    expect(
      res.valueOrNull,
      const RemoteStickerSet(
        name: 'Cats',
        title: 'Cats!',
        stickers: [
          RemoteSticker(
            fileId: 'a',
            kind: RemoteStickerKind.still,
            emoji: '😺',
          ),
          RemoteSticker(
            fileId: 'b',
            kind: RemoteStickerKind.animated,
            thumbnailFileId: 'bt',
          ),
          RemoteSticker(
            fileId: 'c',
            kind: RemoteStickerKind.video,
            thumbnailFileId: 'ct',
          ),
        ],
      ),
    );
  });

  test('fetches a file through getFile and the file endpoint', () async {
    final fake = _FakeTelegram({
      '/botT/getFile': (
        200,
        {
          'ok': true,
          'result': {'file_path': 'stickers/file_1.webp'},
        },
      ),
      '/file/botT/stickers/file_1.webp': (200, [1, 2, 3]),
    });

    final res = await _source(fake).file('a', token: 'T');

    expect(res.valueOrNull, [1, 2, 3]);
  });

  test('a refused token and an unknown set say so', () async {
    final refused = _FakeTelegram({
      '/botBAD/getStickerSet': (
        401,
        {'ok': false, 'error_code': 401, 'description': 'Unauthorized'},
      ),
    });
    final unknown = _FakeTelegram({
      '/botT/getStickerSet': (
        400,
        {
          'ok': false,
          'error_code': 400,
          'description': 'Bad Request: STICKERSET_INVALID',
        },
      ),
    });

    final badToken = await _source(refused).stickerSet('Cats', token: 'BAD');
    final noSet = await _source(unknown).stickerSet('Nope', token: 'T');

    expect(badToken.failureOrNull, isA<AuthFailure>());
    expect(noSet.failureOrNull, isA<NotFoundFailure>());
  });

  test('a failure never carries the token', () async {
    final dio = Dio()
      ..httpClientAdapter = _FakeTelegram({})
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) => h.reject(
            DioException.connectionError(requestOptions: o, reason: 'down'),
          ),
        ),
      );

    final res = await TelegramStickerSource(
      dio: dio,
    ).stickerSet('Cats', token: 'SECRET');

    final failure = res.failureOrNull;
    expect(failure, isA<NetworkFailure>());
    expect('${failure?.message} ${failure?.cause}', isNot(contains('SECRET')));
  });
}
