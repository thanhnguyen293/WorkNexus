import 'dart:convert';
import 'dart:io';

import '../../domain/entities/cookie_import.dart';
import '../../domain/entities/cookie_source.dart';
import '../../domain/value_objects/cookie_browser.dart';
import '../../domain/value_objects/cookie_key.dart';

/// The imported sites, kept as a small JSON file in the support folder. It
/// holds where the cookies came from and their names, never their values.
/// Throws on a file it cannot read or write; a damaged file reads as empty.
class CookieImportStore {
  CookieImportStore({required this._file});

  final Future<File> Function() _file;

  Future<List<CookieImport>> read() async {
    final file = await _file();
    if (!await file.exists()) return const [];
    final Object? decoded;
    try {
      decoded = jsonDecode(await file.readAsString());
    } on FormatException {
      // A damaged file forgets the imports; the cookies themselves stay.
      return const [];
    }
    return [
      if (decoded is List)
        for (final item in decoded)
          if (item is Map) ?_fromJson(item),
    ];
  }

  /// Replaces what is kept with [imports]; none removes the file.
  Future<void> write(List<CookieImport> imports) async {
    final file = await _file();
    if (imports.isEmpty) {
      if (await file.exists()) await file.delete();
      return;
    }
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode([for (final i in imports) _toJson(i)]));
  }

  static Map<String, Object?> _toJson(CookieImport i) => {
    'site': i.site,
    'browser': i.source.browser.name,
    'profileId': i.source.profileId,
    'profileName': i.source.profileName,
    'importedAt': i.importedAt.toUtc().toIso8601String(),
    'keys': [
      for (final k in i.keys) {'host': k.host, 'path': k.path, 'name': k.name},
    ],
  };

  static CookieImport? _fromJson(Map<dynamic, dynamic> json) {
    final browser = CookieBrowser.values.asNameMap()[json['browser']];
    final importedAt = DateTime.tryParse('${json['importedAt']}');
    if (json case {
      'site': final String site,
      'profileId': final String profileId,
      'profileName': final String profileName,
      'keys': final List<dynamic> keys,
    } when browser != null && importedAt != null) {
      return CookieImport(
        site: site,
        source: CookieSource(
          browser: browser,
          profileId: profileId,
          profileName: profileName,
        ),
        importedAt: importedAt,
        keys: [
          for (final k in keys)
            if (k case {
              'host': final String host,
              'path': final String path,
              'name': final String name,
            })
              CookieKey(host: host, path: path, name: name),
        ],
      );
    }
    return null;
  }
}
