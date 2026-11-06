import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/domain/repositories/pinned_certificate_repository.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/mini_apps/domain/entities/trusted_certificate.dart';
import 'package:work_nexus/features/mini_apps/domain/repositories/trusted_certificate_repository.dart';
import 'package:work_nexus/features/mini_apps/domain/usecases/is_trusted_server_certificate.dart';
import 'package:work_nexus/features/mini_apps/domain/value_objects/certificate_fingerprint.dart';

class _Pins extends Mock implements PinnedCertificateRepository {}

class _Trusted extends Mock implements TrustedCertificateRepository {}

void main() {
  const host = 'zentao.example.com';
  final der = [1, 2, 3, 4];
  final fingerprint = certificateFingerprint(der);
  late _Pins pins;
  late _Trusted trusted;
  late IsTrustedServerCertificate isTrusted;

  setUp(() {
    pins = _Pins();
    trusted = _Trusted();
    isTrusted = IsTrustedServerCertificate(pins, trusted);
    when(pins.fingerprints).thenAnswer((_) async => const Ok({}));
    when(trusted.all).thenAnswer((_) async => const Ok([]));
  });

  test('a certificate the chat pinned goes through on any host', () async {
    when(pins.fingerprints).thenAnswer((_) async => Ok({fingerprint}));

    expect(await isTrusted(host: 'other.example.com', der: der), isTrue);
    expect(await isTrusted(host: host, der: [9, 9]), isFalse);
  });

  test('one trusted in a mini app goes through on any port of its host '
      'only', () async {
    when(trusted.all).thenAnswer(
      (_) async => Ok([
        TrustedCertificate(
          origin: 'https://$host:11443',
          error: 'net::ERR_CERT_AUTHORITY_INVALID',
          fingerprint: fingerprint,
        ),
      ]),
    );

    expect(await isTrusted(host: host, der: der), isTrue);
    expect(await isTrusted(host: 'other.example.com', der: der), isFalse);
    expect(await isTrusted(host: host, der: [9, 9]), isFalse);
  });

  test(
    'a site trusted without a fingerprint (Windows) does not count',
    () async {
      when(trusted.all).thenAnswer(
        (_) async => const Ok([
          TrustedCertificate(
            origin: 'https://$host:443',
            error: 'net::ERR_CERT_DATE_INVALID',
          ),
        ]),
      );

      expect(await isTrusted(host: host, der: der), isFalse);
    },
  );

  test('unreadable lists trust nothing', () async {
    when(
      pins.fingerprints,
    ).thenAnswer((_) async => const Err(StorageFailure('db')));
    when(
      trusted.all,
    ).thenAnswer((_) async => const Err(StorageFailure('file')));

    expect(await isTrusted(host: host, der: der), isFalse);
  });
}
