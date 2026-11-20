import '../entities/chat_message.dart';
import '../value_objects/auto_reply_policy.dart';
import '../value_objects/message_content.dart';

/// What to do about reply ideas for an open chat right now.
sealed class AutoReplyDecision {
  const AutoReplyDecision();
}

/// Nothing to ask for until something changes.
final class AutoReplySkip extends AutoReplyDecision {
  const AutoReplySkip();
}

/// Ask again after [wait]: the chat is not quiet yet, was only just opened,
/// or had a run too recently.
final class AutoReplyWait extends AutoReplyDecision {
  const AutoReplyWait(this.wait);

  final Duration wait;
}

/// Ask the AI now.
final class AutoReplyRun extends AutoReplyDecision {
  const AutoReplyRun();
}

/// Whether reply ideas for an open chat's newest message are asked for on
/// their own, within [AutoReplyPolicy]: only for someone else's message
/// that says something (not "ok" or a lone emoji), once per message, with
/// nothing typed, once the chat has been quiet for a while, and within the
/// per-chat and hourly limits.
class ShouldAutoSuggestReplies {
  const ShouldAutoSuggestReplies([this.policy = const AutoReplyPolicy()]);

  final AutoReplyPolicy policy;

  /// Mentions are sent as `[@Name](@#id)`; the name is not what it says.
  static final _mention = RegExp(r'\[@[^\]]+\]\(@#\d+\)');
  static final _wordChar = RegExp(r'[\p{L}\p{N}]', unicode: true);
  static final _notWord = RegExp(r'[^\p{L}\p{N}\s]', unicode: true);
  static final _spaces = RegExp(r'\s+');

  /// Acknowledgements that need no reply of their own.
  static const _acks = {
    'ok',
    'oke',
    'okay',
    'okie',
    'ok a',
    'ok anh',
    'ok em',
    'ok nha',
    'ok nhé',
    'ok luôn',
    'oki',
    'k',
    'kk',
    'ừ',
    'ừm',
    'ừa',
    'uh',
    'um',
    'ờ',
    'vâng',
    'dạ',
    'dạ vâng',
    'yes',
    'yep',
    'no',
    'thanks',
    'thank you',
    'thank',
    'thx',
    'tks',
    'ty',
    'cảm ơn',
    'cám ơn',
    'cmon',
    'haha',
    'hihi',
    'hehe',
    'lol',
    '1',
    '0',
    'đúng rồi',
    'được',
  };

  AutoReplyDecision call({
    required ChatMessage? latest,
    required bool draftEmpty,
    required DateTime now,
    required DateTime openedAt,
    String? handledGid,
    DateTime? lastRunInChat,
    int runsLastHour = 0,
  }) {
    if (latest == null ||
        latest.isMine ||
        latest.deleted ||
        latest.isNotice ||
        latest.gid == handledGid ||
        !draftEmpty ||
        runsLastHour >= policy.hourlyLimit ||
        !worthAnswering(latest.content)) {
      return const AutoReplySkip();
    }
    final age = now.difference(latest.sentAt);
    if (age > policy.maxAge) return const AutoReplySkip();
    final waits = [
      policy.quiet - age,
      policy.settleAfterOpen - now.difference(openedAt),
      if (lastRunInChat != null)
        policy.chatCooldown - now.difference(lastRunInChat),
    ];
    final wait = waits.reduce((a, b) => a > b ? a : b);
    return wait > Duration.zero ? AutoReplyWait(wait) : const AutoReplyRun();
  }

  /// Whether a message says enough to be worth replies: text with at least
  /// two letters or digits that is not just an acknowledgement.
  static bool worthAnswering(MessageContent content) {
    if (content is! TextContent) return false;
    final text = content.text.replaceAll(_mention, ' ');
    if (_wordChar.allMatches(text).length < 2) return false;
    final words = text
        .toLowerCase()
        .replaceAll(_notWord, ' ')
        .trim()
        .replaceAll(_spaces, ' ');
    return !_acks.contains(words);
  }
}
