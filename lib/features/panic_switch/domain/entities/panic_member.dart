import 'package:freezed_annotation/freezed_annotation.dart';

part 'panic_member.freezed.dart';

/// A chat user who could send the sticker or be a direct chat's peer.
@freezed
abstract class PanicMember with _$PanicMember {
  const PanicMember._();

  const factory PanicMember({
    required int userId,
    required String account,
    required String realname,
    String? avatarUrl,
  }) = _PanicMember;

  /// The real name, or the account when the user has none.
  String get displayName => realname.isEmpty ? account : realname;
}
