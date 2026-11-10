import '../entities/zentao_doc.dart';

/// [doc] as a standalone HTML page: its title, then the body, with plain
/// readable styling inlined. Links and images ZenTao wrote relative to its
/// site are made absolute against [baseUrl], so they still resolve once the
/// file is opened from disk.
String renderZenTaoDocHtml(ZenTaoDoc doc, {String? baseUrl}) {
  final title = _escape(doc.title);
  var body = doc.html.trim();
  final base = baseUrl?.replaceAll(RegExp(r'/+$'), '');
  if (base != null && base.isNotEmpty) {
    body = body.replaceAllMapped(
      RegExp(r'''(\s(?:src|href)=["'])(/[^/][^"']*|/)(["'])'''),
      (m) => '${m[1]}$base${m[2]}${m[3]}',
    );
  }
  return '''
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$title</title>
<style>
body { max-width: 860px; margin: 40px auto; padding: 0 16px; font: 16px/1.6 -apple-system, "Segoe UI", sans-serif; color: #1f2328; }
pre { background: #f6f8fa; padding: 12px 16px; border-radius: 6px; overflow-x: auto; }
code { font-family: ui-monospace, Menlo, Consolas, monospace; font-size: 0.9em; }
table { border-collapse: collapse; }
th, td { border: 1px solid #d0d7de; padding: 6px 12px; }
img { max-width: 100%; }
</style>
</head>
<body>
<h1>$title</h1>
$body
</body>
</html>
''';
}

String _escape(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
