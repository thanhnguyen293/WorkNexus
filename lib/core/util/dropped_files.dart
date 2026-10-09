import 'dart:typed_data';

/// A file dragged in from the OS: its name and contents.
typedef DroppedFile = ({String name, Uint8List bytes});

const _imageExtensions = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'};

/// Whether [name] is an image the rich-text editor can show inline.
bool isInlineImageName(String name) {
  final dot = name.lastIndexOf('.');
  return dot >= 0 &&
      _imageExtensions.contains(name.substring(dot + 1).toLowerCase());
}

/// [files] split into inline images and everything else, each in order.
({List<DroppedFile> images, List<DroppedFile> others}) splitDroppedImages(
  List<DroppedFile> files,
) => (
  images: [
    for (final f in files)
      if (isInlineImageName(f.name)) f,
  ],
  others: [
    for (final f in files)
      if (!isInlineImageName(f.name)) f,
  ],
);
