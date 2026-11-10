import 'package:freezed_annotation/freezed_annotation.dart';

import 'zentao_doc_change.dart';

part 'zentao_doc_action.freezed.dart';

/// One entry of a document's history, as ZenTao's History panel lists it.
@freezed
abstract class ZenTaoDocAction with _$ZenTaoDocAction {
  const factory ZenTaoDocAction({
    required String id,

    /// ZenTao's action: `saveddraft`, `edited`, `moved`, `releaseddoc`…
    required String action,

    /// ZenTao's own sentence for it, as plain text without its date
    /// ("edited by ViPham-VN-go") — shown for an action the app doesn't name.
    required String summary,
    DateTime? date,

    /// Who did it (their display name).
    String? actor,

    /// The fields it changed; empty when it records none.
    @Default(<ZenTaoDocChange>[]) List<ZenTaoDocChange> changes,
  }) = _ZenTaoDocAction;
}
