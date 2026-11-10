import 'package:freezed_annotation/freezed_annotation.dart';

import 'zentao_doc_lib.dart';
import 'zentao_doc_summary.dart';

part 'zentao_doc_pins.freezed.dart';

/// The libraries and documents an account keeps on top of the Docs pane, in
/// the order they were pinned.
@freezed
abstract class ZenTaoDocPins with _$ZenTaoDocPins {
  const ZenTaoDocPins._();

  const factory ZenTaoDocPins({
    @Default(<ZenTaoDocLib>[]) List<ZenTaoDocLib> libs,
    @Default(<ZenTaoDocSummary>[]) List<ZenTaoDocSummary> docs,
  }) = _ZenTaoDocPins;

  bool get isEmpty => libs.isEmpty && docs.isEmpty;

  bool hasLib(String id) => libs.any((l) => l.id == id);

  bool hasDoc(String id) => docs.any((d) => d.id == id);

  /// Pins [lib] at the end, or unpins it when already pinned.
  ZenTaoDocPins togglingLib(ZenTaoDocLib lib) => copyWith(
    libs: hasLib(lib.id)
        ? [
            for (final l in libs)
              if (l.id != lib.id) l,
          ]
        : [...libs, lib],
  );

  /// Pins [doc] at the end, or unpins it when already pinned.
  ZenTaoDocPins togglingDoc(ZenTaoDocSummary doc) => copyWith(
    docs: hasDoc(doc.id)
        ? [
            for (final d in docs)
              if (d.id != doc.id) d,
          ]
        : [...docs, doc],
  );
}
