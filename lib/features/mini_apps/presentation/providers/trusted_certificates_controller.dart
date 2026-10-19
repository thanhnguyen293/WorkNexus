import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/service_locator.dart';
import '../../domain/entities/trusted_certificate.dart';
import '../../domain/repositories/trusted_certificate_repository.dart';

/// The certificate problems the user chose to trust, for the pages that meet
/// them and the settings list that forgets them.
class TrustedCertificatesController
    extends AsyncNotifier<List<TrustedCertificate>> {
  TrustedCertificateRepository get _repository =>
      getIt<TrustedCertificateRepository>();

  @override
  Future<List<TrustedCertificate>> build() => _repository.all();

  Future<bool> isOriginTrusted(String origin) =>
      _repository.isOriginTrusted(origin);

  Future<void> trust(String origin, String error) async {
    await _repository.trust(origin, error);
    state = AsyncData(await _repository.all());
  }

  Future<void> forget(TrustedCertificate certificate) async {
    await _repository.forget(certificate);
    state = AsyncData(await _repository.all());
  }

  Future<void> forgetAll() async {
    await _repository.forgetAll();
    state = const AsyncData([]);
  }
}

final trustedCertificatesProvider =
    AsyncNotifierProvider<
      TrustedCertificatesController,
      List<TrustedCertificate>
    >(TrustedCertificatesController.new);
