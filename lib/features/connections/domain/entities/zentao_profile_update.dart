import 'package:freezed_annotation/freezed_annotation.dart';

part 'zentao_profile_update.freezed.dart';

@freezed
abstract class ZenTaoProfileUpdate with _$ZenTaoProfileUpdate {
  const factory ZenTaoProfileUpdate({
    required String realname,
    required String email,
    required String mobile,
    required String phone,
    int? departmentId,
    String? roleCode,
  }) = _ZenTaoProfileUpdate;
}
