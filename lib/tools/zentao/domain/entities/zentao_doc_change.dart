import 'package:freezed_annotation/freezed_annotation.dart';

part 'zentao_doc_change.freezed.dart';

/// One field a history entry changed: its old and new value, or the lines a
/// text diff removed and added. The body ([isBody]) is only said to have
/// changed — ZenTao records it as the editor's whole raw page.
@freezed
abstract class ZenTaoDocChange with _$ZenTaoDocChange {
  const factory ZenTaoDocChange({
    required String field,
    String? from,
    String? to,
    @Default(<String>[]) List<String> removed,
    @Default(<String>[]) List<String> added,
    @Default(false) bool isBody,
  }) = _ZenTaoDocChange;
}
