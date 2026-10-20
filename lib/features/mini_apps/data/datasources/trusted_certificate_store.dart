import 'dart:convert';
import 'dart:io';

/// One trusted site as it is written in the file.
typedef TrustedCertificateRow = ({String origin, String error});

/// The trusted certificates kept as a small JSON file in the support folder.
/// Throws on a file it cannot read or write; a damaged file reads as empty.
class TrustedCertificateStore {
  TrustedCertificateStore({required this._file});

  final Future<File> Function() _file;

  Future<List<TrustedCertificateRow>> read() async {
    final file = await _file();
    if (!await file.exists()) return const [];
    final Object? decoded;
    try {
      decoded = jsonDecode(await file.readAsString());
    } on FormatException {
      // A damaged file trusts nothing; the user is asked again.
      return const [];
    }
    return [
      if (decoded is List)
        for (final item in decoded)
          if (item is Map &&
              item['origin'] is String &&
              item['error'] is String)
            (origin: item['origin'] as String, error: item['error'] as String),
    ];
  }

  /// Replaces what is kept with [rows]; none removes the file.
  Future<void> write(List<TrustedCertificateRow> rows) async {
    final file = await _file();
    if (rows.isEmpty) {
      if (await file.exists()) await file.delete();
      return;
    }
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode([
        for (final row in rows) {'origin': row.origin, 'error': row.error},
      ]),
    );
  }
}
