import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:pasteboard/pasteboard.dart';

/// A file the user chose to send.
typedef ChatAttachment = ({String name, Uint8List bytes});

/// Opens the system file picker (several files; only images with
/// [imagesOnly]).
Future<List<ChatAttachment>> pickChatAttachments({
  bool imagesOnly = false,
}) async {
  final files = await openFiles(
    acceptedTypeGroups: [
      if (imagesOnly)
        const XTypeGroup(
          label: 'images',
          extensions: ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'heic'],
          uniformTypeIdentifiers: ['public.image'],
        ),
    ],
  );
  return [for (final f in files) (name: f.name, bytes: await f.readAsBytes())];
}

/// Files or an image on the clipboard, or null when it only holds text (the
/// caller then pastes text as usual). Copied files (e.g. from Finder) win
/// over image data, which is what a screenshot puts on the clipboard.
Future<List<ChatAttachment>?> readClipboardAttachments() async {
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
