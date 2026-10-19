import 'dart:convert';
import 'dart:io';

import '../../domain/entities/trusted_certificate.dart';
import '../../domain/repositories/trusted_certificate_repository.dart';

/// The trusted certificates kept as a small JSON file in the support folder.
/// Writes follow one another, so two trusts at once lose neither.
class FileTrustedCertificateRepository implements TrustedCertificateRepository {
  FileTrustedCertificateRepository({required this._file});

  final Future<File> Function() _file;
  Future<void> _writes = Future.value();

  @override
  Future<List<TrustedCertificate>> all() async {
    final file = await _file();
    if (!await file.exists()) return const [];
    try {
      final decoded = jsonDecode(await file.readAsString());
      return [
        if (decoded is List)
          for (final item in decoded)
            if (item is Map &&
                item['origin'] is String &&
                item['error'] is String)
              TrustedCertificate(
                origin: item['origin'] as String,
                error: item['error'] as String,
              ),
      ];
    } on FormatException {
      // A damaged file trusts nothing; the user is asked again.
      return const [];
    }
  }

  @override
  Future<bool> isOriginTrusted(String origin) async =>
      (await all()).any((item) => item.origin == origin);

  @override
  Future<void> trust(String origin, String error) => _change(
    (items) => [
      for (final item in items)
        if (item.origin != origin) item,
      TrustedCertificate(origin: origin, error: error),
    ],
  );

  @override
  Future<void> forget(TrustedCertificate certificate) => _change(
    (items) => [
      for (final item in items)
        if (item != certificate) item,
    ],
  );

  @override
  Future<void> forgetAll() => _change((_) => const []);

  Future<void> _change(
    List<TrustedCertificate> Function(List<TrustedCertificate>) change,
  ) {
    final done = _writes.then((_) async {
      final items = change(await all());
      final file = await _file();
      if (items.isEmpty) {
        if (await file.exists()) await file.delete();
        return;
      }
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode([
          for (final item in items)
            {'origin': item.origin, 'error': item.error},
        ]),
      );
    });
    _writes = done.catchError((_) {});
    return done;
  }
}
