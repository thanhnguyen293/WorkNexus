import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/trusted_certificate.dart';
import '../../domain/repositories/trusted_certificate_repository.dart';
import '../datasources/trusted_certificate_store.dart';

/// The trusted certificates in [TrustedCertificateStore]. Changes follow one
/// another, so two trusts at once lose neither.
class LocalTrustedCertificateRepository
    implements TrustedCertificateRepository {
  LocalTrustedCertificateRepository(this._store);

  final TrustedCertificateStore _store;
  Future<void> _changes = Future.value();

  @override
  Future<Result<List<TrustedCertificate>>> all() async {
    try {
      return Ok(await _read());
    } on Exception catch (e) {
      return Err(
        StorageFailure('Could not read the trusted certificates', cause: e),
      );
    }
  }

  @override
  Future<Result<List<TrustedCertificate>>> trust(String origin, String error) =>
      _change(
        (items) => [
          for (final item in items)
            if (item.origin != origin) item,
          TrustedCertificate(origin: origin, error: error),
        ],
      );

  @override
  Future<Result<List<TrustedCertificate>>> forget(
    TrustedCertificate certificate,
  ) => _change(
    (items) => [
      for (final item in items)
        if (item != certificate) item,
    ],
  );

  @override
  Future<Result<List<TrustedCertificate>>> forgetAll() =>
      _change((_) => const []);

  Future<List<TrustedCertificate>> _read() async => [
    for (final row in await _store.read())
      TrustedCertificate(origin: row.origin, error: row.error),
  ];

  Future<Result<List<TrustedCertificate>>> _change(
    List<TrustedCertificate> Function(List<TrustedCertificate>) change,
  ) {
    final done = _changes.then((_) async {
      try {
        final items = change(await _read());
        await _store.write([
          for (final item in items) (origin: item.origin, error: item.error),
        ]);
        return Ok<List<TrustedCertificate>>(items);
      } on Exception catch (e) {
        return Err<List<TrustedCertificate>>(
          StorageFailure('Could not save the trusted certificates', cause: e),
        );
      }
    });
    _changes = done;
    return done;
  }
}
