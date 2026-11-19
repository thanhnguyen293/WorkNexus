import '../../../../core/error/result.dart';

/// The version this computer last ran, to tell after an update that a new
/// one is running.
abstract interface class SeenVersionStore {
  /// Null before the first launch that kept one.
  Future<Result<String?>> lastSeen();

  Future<Result<void>> setLastSeen(String version);
}
