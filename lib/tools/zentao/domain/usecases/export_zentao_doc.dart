import '../../../../core/domain/entities/account.dart';
import '../../../../core/error/result.dart';
import '../entities/zentao_doc.dart';
import '../entities/zentao_doc_export_format.dart';
import '../repositories/zentao_doc_repository.dart';
import 'render_zentao_doc_html.dart';
import 'render_zentao_doc_markdown.dart';

/// Saves [ZenTaoDoc] to the Downloads folder as [ZenTaoDocExportFormat]
/// — Markdown, a standalone HTML page, or the backup of ZenTao's own record
/// — named after its title; returns the saved path.
class ExportZenTaoDoc {
  const ExportZenTaoDoc(this._repository);

  final ZenTaoDocRepository _repository;

  Future<Result<String>> call(
    Account account,
    ZenTaoDoc doc,
    ZenTaoDocExportFormat format,
  ) async {
    final Result<String> text = switch (format) {
      ZenTaoDocExportFormat.markdown => Ok('${zenTaoDocMarkdown(doc)}\n'),
      ZenTaoDocExportFormat.html => Ok(
        renderZenTaoDocHtml(doc, baseUrl: account.baseUrl),
      ),
      ZenTaoDocExportFormat.backup => await _repository.readBackup(
        account.id,
        doc.id,
      ),
    };
    return switch (text) {
      Ok(:final value) => _repository.saveText(
        '${doc.title}.${format.extension}',
        value,
      ),
      Err(:final failure) => Err(failure),
    };
  }
}
