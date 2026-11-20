import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import 'send_text_message.dart';

/// Shares a link (a ticket, say) into one or more chats of one account: the
/// user's [note], when given, above the link, as one message in each chat —
/// the link alone stays on its own line so chat shows its card.
class SendLinkToChats {
  const SendLinkToChats(this._send);

  final SendTextMessage _send;

  /// The message sent: the trimmed note, then the link on the next line.
  static String compose(String link, {String note = ''}) {
    final text = note.trim();
    return text.isEmpty ? link.trim() : '$text\n${link.trim()}';
  }

  /// Sends to each of [toChatGids] in turn; one chat failing does not stop
  /// the others. Fails with the first failure when any did.
  Future<Result<void>> call({
    required String accountId,
    required String link,
    required List<String> toChatGids,
    String note = '',
  }) async {
    if (link.trim().isEmpty) {
      return const Err(UnexpectedFailure('Nothing to send'));
    }
    if (toChatGids.isEmpty) {
      return const Err(UnexpectedFailure('Pick a chat to send to'));
    }
    final text = compose(link, note: note);
    Failure? first;
    for (final chatGid in toChatGids) {
      final result = await _send(
        accountId: accountId,
        chatGid: chatGid,
        text: text,
      );
      if (result case Err(:final failure)) first ??= failure;
    }
    return first == null ? const Ok(null) : Err(first);
  }
}
