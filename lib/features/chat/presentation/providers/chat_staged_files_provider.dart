import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:pasteboard/pasteboard.dart';

import '../../../../core/util/dropped_files.dart';
import 'chat_providers.dart';

/// Files dropped on a composer, held in its input until sent or removed.
/// While any are held the input takes no text.
final chatStagedFilesProvider =
    StateProvider.family<List<DroppedFile>, ChatComposerKey>(
      (ref, key) => const [],
    );

/// A file pasted into a composer: its name and contents.
typedef ClipboardFile = ({String name, Uint8List bytes});

/// Reads what a paste would bring: files or an image, or null when the
/// clipboard holds only text. A provider so tests can stand in for the
/// clipboard plugin, which answers differently on each OS (on Windows an
/// image comes as a temporary file to read).
final chatClipboardFilesProvider =
    Provider<Future<List<ClipboardFile>?> Function()>(
      (ref) => _readClipboardFiles,
    );

/// Copied files (e.g. from Finder) win over image data, which is what a
/// screenshot puts on the clipboard.
Future<List<ClipboardFile>?> _readClipboardFiles() async {
  final paths = await Pasteboard.files();
  if (paths.isNotEmpty) {
    return [
      for (final path in paths)
        if (FileSystemEntity.isFileSync(path))
          (
            name: path.split(Platform.pathSeparator).last,
            bytes: await File(path).readAsBytes(),
          ),
    ];
  }
  final image = await Pasteboard.image;
  if (image != null && image.isNotEmpty) {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return [(name: 'pasted-$stamp.png', bytes: image)];
  }
  return null;
}
