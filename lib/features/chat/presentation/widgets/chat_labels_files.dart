part of 'chat_labels.dart';

// Attachment helpers: file kinds, badges and transfer sizes.

/// Whether a file to send is an image (gets a thumbnail in the preview).
bool isImageAttachment(String name) => const {
  'png',
  'jpg',
  'jpeg',
  'gif',
  'webp',
  'bmp',
}.contains(_extension(name));

String _extension(String name) {
  final dot = name.lastIndexOf('.');
  return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
}

/// Human-readable byte size.
String formatFileSize(int bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    final gb = bytes / 1024 / 1024 / 1024;
    // Whole sizes (limits like 2 GB) read better without ".0".
    return '${gb == gb.roundToDouble() ? gb.toStringAsFixed(0) : gb.toStringAsFixed(1)} GB';
  }
  if (bytes >= 1024 * 1024) {
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '$bytes B';
}

/// A file's size, or — while it transfers ([progress] 0–1) — how much of it
/// has moved: `12.3 MB / 364.2 MB`.
String formatTransfer(int bytes, double? progress) => progress == null
    ? formatFileSize(bytes)
    : '${formatFileSize((bytes * progress.clamp(0, 1)).round())} / '
          '${formatFileSize(bytes)}';

/// Upper-case file extension for the file tile badge (max 4 chars).
String chatFileBadge(String name) {
  final dot = name.lastIndexOf('.');
  if (dot < 0 || dot == name.length - 1) return 'FILE';
  final ext = name.substring(dot + 1).toUpperCase();
  return ext.length > 4 ? ext.substring(0, 4) : ext;
}
