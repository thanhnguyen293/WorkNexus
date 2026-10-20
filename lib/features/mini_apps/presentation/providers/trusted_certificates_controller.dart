import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/trusted_certificate.dart';
import '../../domain/repositories/trusted_certificate_repository.dart';

/// The sites the user chose to trust despite their certificate, for the pages
/// that meet them and the settings list that forgets them. The list read once
/// is the one pages check against; each change replaces it.
class TrustedCertificatesController
    extends AsyncNotifier<List<TrustedCertificate>> {
  TrustedCertificateRepository get _repository =>
      getIt<TrustedCertificateRepository>();

  @override
  Future<List<TrustedCertificate>> build() async =>
      switch (await _repository.all()) {
        Ok(:final value) => value,
        Err(:final failure) => throw failure,
      };

  /// Whether the user trusted [origin]'s certificate, for whatever problem.
  Future<bool> isTrusted(String origin) async =>
      (await future).any((item) => item.origin == origin);

  Future<Result<void>> trust(String origin, String error) =>
      _apply(_repository.trust(origin, error));

  Future<Result<void>> forget(TrustedCertificate certificate) =>
      _apply(_repository.forget(certificate));

  Future<Result<void>> forgetAll() => _apply(_repository.forgetAll());

  Future<Result<void>> _apply(
    Future<Result<List<TrustedCertificate>>> change,
  ) async {
    switch (await change) {
      case Ok(:final value):
        state = AsyncData(value);
        return const Ok(null);
      case Err(:final failure):
        return Err(failure);
    }
  }
}

final trustedCertificatesProvider =
    AsyncNotifierProvider<
      TrustedCertificatesController,
      List<TrustedCertificate>
    >(TrustedCertificatesController.new);
