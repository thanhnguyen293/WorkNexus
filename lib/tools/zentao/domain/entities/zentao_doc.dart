import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/domain/entities/provider_entity.dart';
import 'zentao_doc_person.dart';

part 'zentao_doc.freezed.dart';

/// One ZenTao document (`GET /docs/{id}`). A `text` document carries its body
/// as HTML in [html]; an `attachment` document has an empty body and its
/// content in [files].
@freezed
abstract class ZenTaoDoc with _$ZenTaoDoc {
  const ZenTaoDoc._();

  const factory ZenTaoDoc({
    required String id,
    required String title,
    required String libId,
    @Default('') String html,
    @Default(false) bool isAttachment,
    int? version,

    /// Who wrote it.
    ZenTaoDocPerson? author,

    /// Everyone who edited it, oldest first, each once.
    @Default(<ZenTaoDocPerson>[]) List<ZenTaoDocPerson> editors,
    int? views,
    DateTime? addedDate,
    DateTime? editedDate,
    @Default(<TicketAttachment>[]) List<TicketAttachment> files,
  }) = _ZenTaoDoc;

  bool get hasBody => html.trim().isNotEmpty;
}
