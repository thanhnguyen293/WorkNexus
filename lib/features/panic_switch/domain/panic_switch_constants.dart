/// Fixed facts of the panic switch ("Thầy vô").
abstract final class PanicSwitchConstants {
  /// The file name the sticker is sent under. The chat server gives every
  /// upload a new id and carries no sticker identity, so this reserved name is
  /// what receivers recognise it by.
  static const stickerFileName = 'worknexus-thayvo-v1.png';

  /// The feature is only offered to people signed in to this ZenTao.
  static const zentaoBaseUrl = 'https://zentao.oasoft.xyz:4433/zentao';

  /// The group picked by default until the user chooses one.
  static const defaultGroupName = 'VN Mobile Tester';

  /// A sticker older than this is ignored: a guard against messages that
  /// arrive late (after a reconnect) setting the switch off long after.
  static const freshWindow = Duration(seconds: 30);

  static const defaultDebounceSeconds = 60;
}
