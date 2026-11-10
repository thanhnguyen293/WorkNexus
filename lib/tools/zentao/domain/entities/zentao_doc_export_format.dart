/// What a document can be exported as, ZenTao's web's choices: Markdown,
/// a standalone HTML page, or a backup of ZenTao's own record (JSON).
enum ZenTaoDocExportFormat {
  markdown('md'),
  html('html'),
  backup('json');

  const ZenTaoDocExportFormat(this.extension);

  final String extension;
}
