import 'package:freezed_annotation/freezed_annotation.dart';

part 'person_profile.freezed.dart';

/// What the work tracker knows about a person beyond chat: their place in the
/// organisation and how to reach them. Every field is optional — servers and
/// privileges differ in what they share.
@freezed
abstract class PersonProfile with _$PersonProfile {
  const factory PersonProfile({
    /// Readable department path, e.g. "VN > Flutter VN".
    String? department,

    /// Role code (`dev`, `qa`…) or name, as the server sends it.
    String? role,
    String? email,
    String? mobile,
    String? phone,
    String? gender,
    String? address,
    DateTime? joined,
    DateTime? lastLogin,

    /// Messenger handles: WeChat, QQ, Skype, Slack, WhatsApp, DingTalk.
    String? wechat,
    String? qq,
    String? skype,
    String? slack,
    String? whatsapp,
    String? dingding,
  }) = _PersonProfile;
}
