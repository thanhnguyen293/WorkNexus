import 'dart:io';

/// Platform half of an update: unpacking a downloaded build and swapping it
/// in for the running one.
abstract class UpdateInstaller {
  const UpdateInstaller();

  /// The release asset holding this platform's build.
  String get assetName;

  /// Unpacks [zipPath] into [directory] and returns the path of the new build
  /// inside it (the `.app` on macOS, the folder holding the exe on Windows).
  Future<String> unpack(String zipPath, String directory);

  /// Where the running build lives, which [launchSwap] replaces.
  String get installPath;

  /// Starts a detached helper that waits for this process to exit, replaces
  /// [installPath] with [stagedPath] and starts the app again.
  Future<void> launchSwap(String stagedPath, {required String scriptDir});

  /// The folder the swap writes into: where the app bundle is moved within.
  Directory get writableDirectory => Directory(installPath).parent;

  /// Whether [writableDirectory] can be changed by this user; it cannot when
  /// the app was installed by an admin or runs translocated.
  Future<bool> canReplace() async {
    final probe = File('${writableDirectory.path}/.worknexus-update-probe');
    try {
      await probe.writeAsString('');
      await probe.delete();
      return true;
    } on FileSystemException {
      return false;
    }
  }
}

/// Runs [executable] and throws when it fails, so callers map one exception.
Future<void> runChecked(String executable, List<String> arguments) async {
  final result = await Process.run(executable, arguments);
  if (result.exitCode != 0) {
    throw ProcessException(
      executable,
      arguments,
      '${result.stderr}'.trim(),
      result.exitCode,
    );
  }
}
