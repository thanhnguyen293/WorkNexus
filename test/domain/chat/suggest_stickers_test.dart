import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_message.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_sticker.dart';
import 'package:work_nexus/features/chat/domain/usecases/sticker_matching.dart';
import 'package:work_nexus/features/chat/domain/usecases/suggest_reply_stickers.dart';
import 'package:work_nexus/features/chat/domain/usecases/suggest_stickers.dart';
import 'package:work_nexus/features/chat/domain/value_objects/message_content.dart';

ChatSticker _sticker(
  String id,
  String emoji, [
  List<String> words = const [],
]) => ChatSticker(
  id: id,
  pack: 'p',
  name: '$id.webp',
  location: id,
  emoji: emoji,
  keywords: words,
);

final _laugh = _sticker('laugh', '😂🤣');
final _rofl = _sticker('rofl', '🤣');
final _thanks = _sticker('thanks', '🙏😊', ['cam on']);
final _smile = _sticker('smile', '😊');
final _ok = _sticker('ok', '👌👍');
final _heart = _sticker('heart', '❤️');
final _coder = _sticker('coder', '👨‍💻');
final _think = _sticker('think', '🤔');
final _shock = _sticker('shock', '😱😳');
final _seen = _sticker('seen', '👀');
final _nope = _sticker('nope', '🙅');
final _plead = _sticker('plead', '🥺');
final _untagged = _sticker('mine', '');
final _all = [
  _laugh,
  _rofl,
  _thanks,
  _smile,
  _ok,
  _heart,
  _coder,
  _think,
  _shock,
  _seen,
  _nope,
  _plead,
  _untagged,
];

ChatMessage _message(
  String text, {
  bool mine = false,
  DateTime? at,
  MessageContent? content,
}) => ChatMessage(
  accountId: 'a',
  gid: 'g',
  chatGid: 'c',
  senderId: 2,
  sentAt: at ?? DateTime(2026, 11, 18, 10),
  content: content ?? TextContent(text),
  isMine: mine,
);

void main() {
  group('StickerMatching', () {
    test('finds emoji whole, without the presentation selector', () {
      expect(StickerMatching.emojiIn('ok 👨‍💻 and ❤️ 👍🏽'), [
        '👨‍💻',
        '❤',
        '👍🏽',
      ]);
    });

    test('finds whole words only, the last typed first', () {
      final words = StickerMatching.words('Cảm ơn, haha!');
      expect(words, 'cam on haha');
      expect(StickerMatching.keysIn(words, ['haha', 'cam on', 'on h']), [
        'haha',
        'cam on',
      ]);
      // "yêu cầu" is not "yêu".
      expect(StickerMatching.keysIn('yeu cau review', ['iu']), isEmpty);
    });
  });

  group('SuggestStickers', () {
    const suggest = SuggestStickers();

    test("a sticker's own words come first and replace the draft", () {
      final result = suggest('Cảm ơn', _all);
      expect(result.stickers.first, _thanks);
      expect(result.replacesDraft, isTrue);
    });

    test('words pick stickers by emoji, a primary emoji first', () {
      final result = suggest('haha', _all);
      expect(result.stickers, [_laugh, _rofl]);
      expect(result.replacesDraft, isTrue);
    });

    test('a typed emoji picks stickers carrying it', () {
      expect(suggest('❤️', _all).stickers, [_heart]);
      expect(suggest('đang code 👨‍💻', _all).stickers.first, _coder);
    });

    test('punctuation and emoticons typed alone pick stickers', () {
      final question = suggest('???', _all);
      expect(question.stickers.first, _think);
      expect(question.replacesDraft, isTrue);
      expect(suggest('?!', _all).stickers.first, _shock);
      expect(suggest('=)))', _all).stickers.first, _laugh);
      expect(suggest('<3', _all).stickers, [_heart]);
      expect(suggest('.', _all).stickers, isEmpty);
    });

    test('a number typed alone says yes or no, and is replaced', () {
      final yes = suggest('1', _all);
      expect(yes.stickers.take(2), [_ok, _seen]);
      expect(yes.replacesDraft, isTrue);
      expect(suggest(' 0 ', _all).stickers.first, _nope);
      // Inside a sentence a number is only a number.
      expect(suggest('còn 1 bug', _all).stickers, isEmpty);
    });

    test('a question mark ending a sentence adds a thinking sticker', () {
      final result = suggest('xong chưa?', _all);
      expect(result.stickers, contains(_think));
      expect(result.replacesDraft, isFalse);
    });

    test('a longer draft keeps its text when a sticker is sent', () {
      final result = suggest('ok anh để em xem', _all);
      // "xem" (look) is the last word, so its sticker leads.
      expect(result.stickers.take(2), [_seen, _ok]);
      expect(result.replacesDraft, isFalse);
    });

    test('nothing for long drafts, unknown words or untagged stickers', () {
      expect(
        suggest('haha nhưng mà cái này dài quá rồi đấy', _all).stickers,
        isEmpty,
      );
      expect(suggest('deadline thứ sáu', _all).stickers, isEmpty);
      expect(suggest('', _all).stickers, isEmpty);
      expect(suggest('haha', [_untagged]).stickers, isEmpty);
    });
  });

  group('SuggestReplyStickers', () {
    const suggest = SuggestReplyStickers();
    final now = DateTime(2026, 11, 18, 11);

    test('thanks is answered with a smile, not thanks back', () {
      final stickers = suggest(_message('Cảm ơn anh nhé'), _all, now: now);
      expect(stickers.first, _smile);
    });

    test('a lone question mark is answered with a thinking sticker', () {
      expect(suggest(_message('?'), _all, now: now).first, _think);
      expect(suggest(_message('=))'), _all, now: now).first, _laugh);
    });

    test('a lone 1 is answered with a thumbs up, a 0 with a plea', () {
      expect(suggest(_message('1'), _all, now: now).first, _ok);
      expect(suggest(_message('0'), _all, now: now).first, _plead);
    });

    test('an emoji sent alone is echoed', () {
      final big = _message('', content: const EmojiContent('😂'));
      expect(suggest(big, _all, now: now).first, _laugh);
    });

    test("nothing for one's own, old or non-text messages", () {
      expect(suggest(_message('haha', mine: true), _all, now: now), isEmpty);
      expect(
        suggest(_message('haha', at: DateTime(2026, 11, 16)), _all, now: now),
        isEmpty,
      );
      expect(
        suggest(
          _message(
            '',
            content: const ImageContent(fileId: 1, name: 'a', size: 1, time: 1),
          ),
          _all,
          now: now,
        ),
        isEmpty,
      );
      expect(suggest(null, _all, now: now), isEmpty);
    });
  });
}
