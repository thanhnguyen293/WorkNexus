import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/remote_sticker_set.dart';
import '../../domain/repositories/sticker_pack_source.dart';

/// Telegram sticker sets through the Bot API (`getStickerSet`, `getFile`).
///
/// The bot token is part of every URL, so this keeps a Dio of its own with no
/// logger: the app's request log must never hold it.
class TelegramStickerSource implements StickerPackSource {
  TelegramStickerSource({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 60),
            ),
          );

  /// Telegram explains a refusal in the body, so a 4xx is read, not thrown.
  static bool _readable(int? status) => status != null && status < 500;

  static const _api = 'https://api.telegram.org';

  final Dio _dio;

  @override
  Future<Result<RemoteStickerSet>> stickerSet(
    String name, {
    required String token,
  }) async {
    final res = await _call(token, 'getStickerSet', {'name': name});
    return switch (res) {
      Ok(:final value) => _set(value),
      Err(:final failure) => Err(failure),
    };
  }

  @override
  Future<Result<Uint8List>> file(String fileId, {required String token}) async {
    final info = await _call(token, 'getFile', {'file_id': fileId});
    if (info case Err(:final failure)) return Err(failure);
    final path = switch (info) {
      Ok(value: {'file_path': final String path}) => path,
      _ => null,
    };
    if (path == null) {
      return const Err(NotFoundFailure('Telegram gave no file for a sticker'));
    }
    return _guard(() async {
      final res = await _dio.get<List<int>>(
        '$_api/file/bot$token/$path',
        options: Options(
          responseType: ResponseType.bytes,
          validateStatus: _readable,
        ),
      );
      final data = res.data;
      if (res.statusCode != 200 || data == null || data.isEmpty) {
        return const Err(
          NotFoundFailure('A sticker file could not be fetched'),
        );
      }
      return Ok(Uint8List.fromList(data));
    });
  }

  /// Calls Bot API [method], giving its `result`.
  Future<Result<Map<String, dynamic>>> _call(
    String token,
    String method,
    Map<String, String> params,
  ) => _guard(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '$_api/bot$token/$method',
      queryParameters: params,
      options: Options(validateStatus: _readable),
    );
    final body = res.data;
    if (body case {'ok': true, 'result': final Map<String, dynamic> result}) {
      return Ok(result);
    }
    final reason = body?['description']?.toString() ?? 'Telegram refused';
    return Err(switch (res.statusCode) {
      401 => AuthFailure('The Telegram bot token was refused: $reason'),
      400 when reason.contains('STICKERSET_INVALID') => NotFoundFailure(
        'No sticker set has this link: $reason',
      ),
      _ => UnexpectedFailure(reason),
    });
  });

  static Future<Result<T>> _guard<T>(Future<Result<T>> Function() run) async {
    try {
      return await run();
    } on DioException catch (e) {
      // Never e.requestOptions.uri: it holds the token.
      return Err(
        NetworkFailure('Telegram could not be reached', cause: e.type),
      );
    } on FormatException catch (e) {
      return Err(ParseFailure('Telegram sent something unreadable', cause: e));
    }
  }

  static Result<RemoteStickerSet> _set(Map<String, dynamic> json) {
    final name = json['name'];
    final stickers = json['stickers'];
    if (name is! String || stickers is! List) {
      return const Err(ParseFailure('Telegram sent an unreadable sticker set'));
    }
    return Ok(
      RemoteStickerSet(
        name: name,
        title: json['title'] is String ? json['title'] as String : name,
        stickers: [
          for (final s in stickers.whereType<Map<String, dynamic>>())
            if (s['file_id'] case final String fileId)
              RemoteSticker(
                fileId: fileId,
                kind: s['is_video'] == true
                    ? RemoteStickerKind.video
                    : s['is_animated'] == true
                    ? RemoteStickerKind.animated
                    : RemoteStickerKind.still,
                // `thumb` is the field's name in older Bot API versions.
                thumbnailFileId: switch (s['thumbnail'] ?? s['thumb']) {
                  {'file_id': final String id} => id,
                  _ => null,
                },
                emoji: s['emoji'] is String ? s['emoji'] as String : '',
              ),
        ],
      ),
    );
  }
}
