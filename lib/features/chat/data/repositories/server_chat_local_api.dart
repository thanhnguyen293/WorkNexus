import 'dart:io';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/repositories/chat_local_api.dart';
import '../datasources/chat_local_api_server.dart';

/// [ChatLocalApi] served by [ChatLocalApiServer] on localhost.
class ServerChatLocalApi implements ChatLocalApi {
  ServerChatLocalApi(this._server);

  final ChatLocalApiServer _server;

  @override
  Future<Result<void>> start(LocalTextSend send) async {
    try {
      await _server.start(send);
      return const Ok(null);
    } on SocketException catch (e) {
      return Err(NetworkFailure('Could not open the local chat API', cause: e));
    } on FileSystemException catch (e) {
      return Err(
        StorageFailure('Could not write the local chat API file', cause: e),
      );
    } on ProcessException catch (e) {
      return Err(
        StorageFailure('Could not protect the local chat API file', cause: e),
      );
    }
  }

  @override
  Future<Result<void>> stop() async {
    try {
      await _server.stop();
      return const Ok(null);
    } on FileSystemException catch (e) {
      return Err(
        StorageFailure('Could not remove the local chat API file', cause: e),
      );
    }
  }
}
