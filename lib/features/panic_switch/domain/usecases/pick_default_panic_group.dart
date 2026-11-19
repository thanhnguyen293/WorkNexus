import '../../../chat/domain/entities/chat_conversation.dart';
import '../panic_switch_constants.dart';

/// The group to use before the user picks one: the one named
/// [PanicSwitchConstants.defaultGroupName], when the account is in it. Only
/// letters and digits are compared — the team's group is "VN Mobile+Tester".
class PickDefaultPanicGroup {
  const PickDefaultPanicGroup();

  String? call(List<ChatConversation> conversations) {
    final wanted = _key(PanicSwitchConstants.defaultGroupName);
    for (final c in conversations) {
      if (c.type == ChatType.group && _key(c.name) == wanted) {
        return c.gid;
      }
    }
    return null;
  }

  static String _key(String name) => name.toLowerCase().replaceAll(
    RegExp(r'[^\p{L}\p{N}]', unicode: true),
    '',
  );
}
