import '../entities/chat_message.dart';
import 'message_content.dart';

/// What kind of attachment a message carries, for storage breakdowns.
enum ChatMediaKind { image, video, file }

const _videoExtensions = {'mp4', 'mov', 'm4v', 'webm', 'mkv', 'avi'};

/// Whether [name] has a video file's extension.
bool isVideoName(String name) {
  final dot = name.lastIndexOf('.');
  final ext = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  return _videoExtensions.contains(ext);
}

/// Whether a file message holds a video (by MIME type or extension).
bool isVideoFile(FileContent file) =>
    (file.mimeType?.startsWith('video/') ?? false) || isVideoName(file.name);

/// The kind of [content]'s attachment; null when it has none.
ChatMediaKind? chatMediaKindOf(MessageContent content) => switch (content) {
  ImageContent() => ChatMediaKind.image,
  final FileContent file when isVideoFile(file) => ChatMediaKind.video,
  FileContent() => ChatMediaKind.file,
  _ => null,
};

/// Whether [message] is drawn bare — an image, a large emoji or a video —
/// rather than inside a bubble. An own video still uploading counts too: it
/// is drawn as a video already, so it keeps one look from send to sent.
bool chatShowsAsMedia(ChatMessage message) =>
    !message.deleted &&
    switch (message.content) {
      ImageContent() || EmojiContent() => true,
      final FileContent f =>
        isVideoFile(f) && (f.fileId > 0 || message.sendState != SendState.sent),
      _ => false,
    };
