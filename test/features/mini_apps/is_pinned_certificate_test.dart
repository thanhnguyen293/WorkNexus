import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/domain/repositories/pinned_certificate_repository.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/mini_apps/domain/usecases/is_pinned_certificate.dart';

class _Pins extends Mock implements PinnedCertificateRepository {}

void main() {
  final der = [1, 2, 3, 4];
  final pin = sha256.convert(der).toString().toUpperCase();
  late _Pins pins;

  setUp(() => pins = _Pins());

  test('the pinned certificate is let through', () async {
    when(pins.fingerprints).thenAnswer((_) async => Ok({pin}));

    expect(await IsPinnedCertificate(pins)(der), isTrue);
  });

  test('any other certificate is not', () async {
    when(pins.fingerprints).thenAnswer((_) async => Ok({pin}));

    expect(await IsPinnedCertificate(pins)([9, 9, 9]), isFalse);
  });

  test('unreadable pins trust nothing', () async {
    when(
      pins.fingerprints,
    ).thenAnswer((_) async => const Err(StorageFailure('db')));

    expect(await IsPinnedCertificate(pins)(der), isFalse);
  });
}
