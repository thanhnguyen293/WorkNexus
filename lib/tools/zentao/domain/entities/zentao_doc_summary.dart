import 'package:freezed_annotation/freezed_annotation.dart';

part 'zentao_doc_summary.freezed.dart';

/// A document as a library's list shows it (`GET /docs?lib=`).
@freezed
abstract class ZenTaoDocSummary with _$ZenTaoDocSummary {
  const factory ZenTaoDocSummary({
    required String id,
    required String title,
    required String libId,

    /// `open`, `private`, `custom`… — a non-open document may refuse a read.
    String? acl,
  }) = _ZenTaoDocSummary;
}
