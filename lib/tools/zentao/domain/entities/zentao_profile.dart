import 'package:freezed_annotation/freezed_annotation.dart';

part 'zentao_profile.freezed.dart';

@freezed
abstract class ZenTaoProfile with _$ZenTaoProfile {
  const factory ZenTaoProfile({
    required String accountId,
    required String account,
    required String realname,
    int? userId,
    int? departmentId,
    String? roleCode,
    String? avatarUrl,
    String? gender,
    String? department,
    String? role,
    String? joined,
    String? privilege,
    String? email,
    String? mobile,
    String? phone,
    String? wechat,
    String? qq,
    String? zipcode,
    String? address,
    String? svnGitAccount,
    String? skype,
    int? visits,
    String? whatsapp,
    String? lastLogin,
    String? slack,
    String? lastIp,
    String? dingding,
  }) = _ZenTaoProfile;
}
