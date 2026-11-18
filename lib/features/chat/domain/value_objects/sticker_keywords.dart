/// Words and short phrases people type, folded (lower case, no Vietnamese
/// diacritics), and the emoji of the stickers that say the same thing, most
/// fitting first. Vietnamese and English, as the team writes both.
///
/// Folding makes many short Vietnamese words alike (`yeu` is yêu and the
/// yêu of yêu cầu, `hop` is họp and hợp), so such words are only listed in
/// a phrase that leaves no doubt (`di hop`, `thuong qua`).
const Map<String, String> kStickerKeywordEmoji = {
  // Thanks, sorry.
  'cam on': '🙏😊', 'thanks': '🙏😊', 'thank you': '🙏😊', 'tks': '🙏',
  'thank': '🙏', 'xin loi': '🙏😅', 'sorry': '🙏😅',
  // Yes, ok, agreed.
  'ok': '👌👍', 'oke': '👌👍', 'okay': '👌👍', 'okie': '👌👍', 'dc roi': '👌',
  'duoc roi': '👌👍', 'yes': '👍', 'dong y': '👍', 'chuan luon': '👍',
  'lgtm': '👍',
  'hieu roi': '👌', 'got it': '👌', 'nhat tri': '👍',
  // Laughing, happy.
  'haha': '😂🤣😆', 'hihi': '🤭😆', 'hehe': '😁😆', 'kkk': '😂🤣',
  'lol': '😂🤣', 'buon cuoi': '😂', 'cuoi xiu': '😂😆', 'vui': '😄😊',
  'hay qua': '🤩👍',
  // Sad, tired, angry, scared, surprised.
  'buon': '😢😞', 'huhu': '😭😢', 'khoc': '😭😢', 'sad': '😢😞',
  'met': '😮‍💨😴', 'tired': '😮‍💨😴', 'tuc': '😠😡', 'buc': '😠😡',
  'angry': '😠😡', 'so qua': '😱😨', 'omg': '😱😮', 'wow': '🤩😮',
  'troi oi': '😱😮', 'that a': '😮😳', 'that sao': '😮😳',
  // Hello, bye, love, praise.
  'chao': '👋😊', 'hello': '👋😊', 'hi': '👋', 'bye': '👋',
  'tam biet': '👋', 'iu': '❤️😍', 'love': '❤️😍', 'thuong qua': '❤️🥺',
  'tuyet voi': '🤩👍', 'great': '🤩👍', 'awesome': '🤩', 'gioi qua': '👍🤩',
  'dinh qua': '🤩', 'ngau': '😎', 'cool': '😎',
  // Thinking, unsure, don't care.
  'hmm': '🤔', 'suy nghi': '🤔', 'sao vay': '🤔', 'khong biet': '🤷',
  'ko biet': '🤷', 'ke no': '🤷', 'whatever': '🤷', 'khong quan tam': '🤷',
  // Work.
  'gap': '🚨', 'urgent': '🚨', 'xong': '✅', 'done': '✅', 'da xong': '✅',
  'fix': '🛠️✅', 'da fix': '✅🛠️', 'dang lam': '👨‍💻💻', 'working': '💻',
  'cho chut': '⏳', 'doi chut': '⏳', 'wait': '⏳', 'hop thoi': '📅',
  'di hop': '📅', 'cuoc hop': '📅',
  'meeting': '📅', 'ship': '🚀', 'deploy': '🚀', 'release': '🚀',
  'review': '👀', 'check': '👀', 'xem': '👀', 'code': '💻',
  // Everyday.
  'chuc mung': '🥳🎉', 'congrats': '🥳🎉', 'sinh nhat': '🥳🎂',
  'birthday': '🥳🎂', 'party': '🥳🎉', 'di ngu': '😴💤', 'buon ngu': '😴',
  'sleep': '😴💤', 'cafe': '☕', 'coffee': '☕', 'ca phe': '☕',
  'an trua': '😋', 'doi bung': '😋', 'len luong': '🤑💰',
  'money': '🤑💰', 'troi mua': '☔🌧️', 'nghe nhac': '🎶🎧', 'music': '🎶🎧',
  'game': '🎮', 'hoc bai': '🤓', 'cau nguyen': '🙏', 'please': '🙏',
  'giup voi': '🙏',
};

/// What a message someone sent is about, folded, and the emoji of the
/// stickers that answer it — not the same as [kStickerKeywordEmoji]: "thank
/// you" is answered with a smile, not with thanks back.
const Map<String, String> kStickerReplyEmoji = {
  'cam on': '😊👌🙏',
  'thanks': '😊👌',
  'thank you': '😊👌',
  'tks': '😊👌',
  'xin loi': '😊👌',
  'sorry': '😊👌',
  'chao': '👋😊',
  'hello': '👋😊',
  'hi': '👋😊',
  'bye': '👋',
  'tam biet': '👋',
  'good morning': '👋☕',
  'chao buoi sang': '👋☕',
  'haha': '😂🤣',
  'hihi': '😆🤭',
  'hehe': '😆',
  'kkk': '😂🤣',
  'lol': '😂🤣',
  'chuc mung': '🙏🥳',
  'congrats': '🙏🥳',
  'sinh nhat': '🥳🎉🎂',
  'birthday': '🥳🎉🎂',
  'gap': '👨‍💻👌',
  'urgent': '👨‍💻👌',
  'xong': '👍🤩🎉',
  'done': '👍🤩🎉',
  'da fix': '👍🤩',
  'fixed': '👍🤩',
  'ship': '🚀🎉',
  'deploy': '🚀👍',
  'release': '🚀🎉',
  'review': '👀👌',
  'check': '👀👌',
  'xem giup': '👀👌',
  'duoc khong': '👌👍🤔',
  'co the giup': '👌👍',
  'giup': '👌👍',
  'please': '👌👍',
  'can you': '👌👍',
  'hop thoi': '📅👌',
  'di hop': '📅👌',
  'meeting': '📅👌',
  'buon': '🥺😢',
  'met': '🥺☕',
  'tired': '🥺☕',
  'bi om': '🥺',
  'ok': '👍',
  'oke': '👍',
  'okay': '👍',
  'iu': '❤️😍',
  'love': '❤️😍',
  'an trua': '😋',
  'an com': '😋',
  'lunch': '😋',
  'cafe': '☕',
  'coffee': '☕',
};
