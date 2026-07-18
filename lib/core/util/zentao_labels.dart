/// Display labels for ZenTao's coded fields (severity / bug type), shared by the
/// detail panel and any board chip. Lives in `core/` because the ZenTao bug
/// entity is a shared-kernel type (`core/domain`) consumed by ≥ 2 features.
///
/// ZenTao ships these as configurable server-side dictionaries; the maps below
/// cover the stock English set and fall back to the raw code when unknown.
library;

/// ZenTao `severity` (1 = most severe … 4 = least) → short label.
String? zentaoSeverityLabel(int? severity) => switch (severity) {
  1 => 'Critical',
  2 => 'Major',
  3 => 'Minor',
  4 => 'Trivial',
  _ => null,
};

const _bugTypes = <String, String>{
  'codeerror': 'Code error',
  'config': 'Config',
  'install': 'Installation',
  'security': 'Security',
  'performance': 'Performance',
  'standard': 'Standard',
  'automation': 'Automation',
  'designdefect': 'Design defect',
  'interface': 'Interface',
  'designchange': 'Design change',
  'others': 'Others',
};

/// ZenTao `type` code (e.g. `codeerror`) → readable label; unknown codes are
/// returned capitalized.
String? zentaoBugTypeLabel(String? type) {
  final code = type?.trim().toLowerCase();
  if (code == null || code.isEmpty) return null;
  final mapped = _bugTypes[code];
  if (mapped != null) return mapped;
  return code[0].toUpperCase() + code.substring(1);
}

const _resolutions = <String, String>{
  'bydesign': 'By design',
  'duplicate': 'Duplicate',
  'external': 'External',
  'fixed': 'Fixed',
  'notrepro': 'Irreproducible',
  'willnotfix': "Won't fix",
  'postponed': 'Postponed',
  'tostory': 'Converted to story',
};

/// ZenTao bug `resolution` code (e.g. `fixed`) → readable label. Unknown codes
/// are returned as-is; null/empty → null.
String? zentaoResolutionLabel(String? resolution) {
  final code = resolution?.trim().toLowerCase();
  if (code == null || code.isEmpty) return null;
  return _resolutions[code] ?? resolution!.trim();
}

/// A human-readable file size (`39124123` → `37.3 MB`). Null/negative → null.
String? formatFileSize(int? bytes) {
  if (bytes == null || bytes < 0) return null;
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var size = bytes / 1024;
  var unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit++;
  }
  final rounded = size >= 100
      ? size.toStringAsFixed(0)
      : size.toStringAsFixed(1);
  return '$rounded ${units[unit]}';
}
