import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../repositories/chat_repository.dart';

/// Sends a code snippet the way the official client does (its "send code"
/// dialog): kept verbatim, in a [languages] entry, with an optional name.
/// A blank snippet, or one over [maxLength], is rejected rather than sent.
class SendCodeMessage {
  const SendCodeMessage(this._repository);

  final ChatRepository _repository;

  /// The official client's own limit.
  static const maxLength = 20000;

  /// The plain-text choice, and the official client's default.
  static const plainText = 'text';

  /// Languages offered for a snippet, as sent on the wire.
  static const languages = [
    plainText,
    'bash',
    'c',
    'cpp',
    'csharp',
    'css',
    'dart',
    'go',
    'html',
    'java',
    'javascript',
    'json',
    'kotlin',
    'markdown',
    'php',
    'python',
    'ruby',
    'rust',
    'sql',
    'swift',
    'typescript',
    'xml',
    'yaml',
  ];

  Future<Result<void>> call({
    required String accountId,
    required String chatGid,
    required String code,
    String language = plainText,
    String? name,
    int? replyToId,
  }) async {
    if (code.trim().isEmpty) {
      return const Err(ValidationFailure('Cannot send empty code'));
    }
    if (code.length > maxLength) {
      return const Err(ValidationFailure('Code is too long'));
    }
    final trimmedName = name?.trim();
    return _repository.sendCode(
      accountId,
      chatGid,
      code: code,
      language: language,
      name: trimmedName == null || trimmedName.isEmpty ? null : trimmedName,
      replyToId: replyToId,
    );
  }
}
