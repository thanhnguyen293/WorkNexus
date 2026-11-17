import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/chat/data/datasources/chat_local_api_server.dart';
import 'package:work_nexus/features/chat/data/repositories/server_chat_local_api.dart';

void main() {
  Future<Result<void>> send({
    required String accountId,
    required String chatGid,
    required String text,
    required bool markdown,
  }) async => const Ok(null);

  test(
    'a folder it cannot write to is a StorageFailure, not a throw',
    () async {
      final api = ServerChatLocalApi(
        ChatLocalApiServer(
          directory: () async =>
              throw const FileSystemException('read-only', '/nowhere'),
        ),
      );
      final result = await api.start(send);
      expect(result, isA<Err<void>>());
      expect((result as Err<void>).failure, isA<StorageFailure>());
      expect(await api.stop(), isA<Ok<void>>());
    },
  );

  test('starts and stops cleanly', () async {
    final dir = await Directory.systemTemp.createTemp('wn_local_api_repo');
    addTearDown(() => dir.delete(recursive: true));
    final api = ServerChatLocalApi(
      ChatLocalApiServer(directory: () async => dir),
    );
    expect(await api.start(send), isA<Ok<void>>());
    expect(
      await File(
        '${dir.path}/${ChatLocalApiServer.discoveryFileName}',
      ).exists(),
      isTrue,
    );
    expect(await api.stop(), isA<Ok<void>>());
  });
}
