import 'package:freezed_annotation/freezed_annotation.dart';

part 'zentao_department.freezed.dart';

@freezed
abstract class ZenTaoDepartment with _$ZenTaoDepartment {
  const factory ZenTaoDepartment({
    required int id,
    required String name,
    required int parentId,
    required String path,
  }) = _ZenTaoDepartment;
}
