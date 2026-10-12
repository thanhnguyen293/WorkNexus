/// The sticker set named by a Telegram link (`https://t.me/addstickers/Name`,
/// with or without the scheme or `www.`) or by its bare name; null for
/// anything else.
class ParseStickerPackLink {
  const ParseStickerPackLink();

  static final _link = RegExp(
    r'^(?:https?://)?(?:www\.)?(?:t|telegram)\.me/addstickers/([A-Za-z0-9_]+)/?(?:\?.*)?$',
  );
  static final _name = RegExp(r'^[A-Za-z0-9_]+$');

  String? call(String input) {
    final value = input.trim();
    if (_link.firstMatch(value) case final match?) return match.group(1);
    return _name.hasMatch(value) ? value : null;
  }
}
