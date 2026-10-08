import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_user.freezed.dart';

/// A ZenTao user as known to chat.
@freezed
abstract class ChatUser with _$ChatUser {
  const factory ChatUser({
    required String accountId,
    required int userId,
    required String account,
    required String realname,
    String? avatarUrl,
    @Default(false) bool deleted,
    String? email,
    String? mobile,
    String? phone,
    String? role,

    /// xxd presence (`online`, `away`, `busy`, `offline`…).
    String? status,
  }) = _ChatUser;
}
