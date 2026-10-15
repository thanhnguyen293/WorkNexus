import 'failure.dart';
import 'result.dart';

/// Runs [run] and keeps a thrown exception from crossing the layer boundary:
/// it comes back as a [StorageFailure] carrying [message] (rule 11.1). For the
/// local repositories, which all end their writes and reads the same way.
Future<Result<T>> guardStorage<T>(
  String message,
  Future<T> Function() run,
) async {
  try {
    return Ok(await run());
  } on Exception catch (e) {
    return Err(StorageFailure(message, cause: e));
  }
}
