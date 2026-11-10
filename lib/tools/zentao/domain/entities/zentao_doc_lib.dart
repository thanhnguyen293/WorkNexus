import 'package:freezed_annotation/freezed_annotation.dart';

part 'zentao_doc_lib.freezed.dart';

/// A ZenTao document library (`GET /doclibs`). The server sends no space or
/// type for it, so libraries are listed flat.
@freezed
abstract class ZenTaoDocLib with _$ZenTaoDocLib {
  const factory ZenTaoDocLib({required String id, required String name}) =
      _ZenTaoDocLib;
}
