import '../panic_switch_constants.dart';

/// The two triggers of the panic switch, running side by side, each with its
/// own sticker, chat and debounce.
enum PanicTrigger {
  /// The team's group, with the "Thầy vô" sticker: a left triple click.
  release(PanicSwitchConstants.stickerFileName),

  /// The demo chat, with the demo sticker, only in demo mode: a right triple
  /// click.
  demo(PanicSwitchConstants.demoStickerFileName);

  const PanicTrigger(this.stickerFileName);

  /// The reserved name the sticker travels under, which receivers tell the
  /// two triggers apart by.
  final String stickerFileName;

  /// The trigger whose sticker is called [name], if any.
  static PanicTrigger? ofSticker(String name) {
    final lower = name.toLowerCase();
    for (final t in values) {
      if (t.stickerFileName == lower) return t;
    }
    return null;
  }
}
