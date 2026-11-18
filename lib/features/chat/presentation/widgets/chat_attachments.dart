import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

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

/// Asks where to save a file called [suggestedName]; null when cancelled.
Future<String?> pickSaveLocation(String suggestedName) async =>
    (await getSaveLocation(suggestedName: suggestedName))?.path;
