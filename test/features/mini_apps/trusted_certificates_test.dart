import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/mini_apps/data/datasources/trusted_certificate_store.dart';
import 'package:work_nexus/features/mini_apps/data/repositories/local_trusted_certificate_repository.dart';
import 'package:work_nexus/features/mini_apps/domain/entities/trusted_certificate.dart';
import 'package:work_nexus/features/mini_apps/domain/value_objects/certificate_problem.dart';
import 'package:work_nexus/features/mini_apps/presentation/providers/trusted_certificates_controller.dart';
import 'package:work_nexus/features/mini_apps/presentation/util/mini_app_certificate_guard.dart';
import 'package:work_nexus/features/mini_apps/presentation/widgets/mini_app_trusted_certificates_section.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

const _expired = 'net::ERR_CERT_DATE_INVALID';
const _site = 'https://zentao.example.com:4433';

class _FakeController extends TrustedCertificatesController {
  _FakeController(this.initial);

  final List<TrustedCertificate> initial;

  @override
  Future<List<TrustedCertificate>> build() async => initial;

  @override
  Future<Result<void>> forget(TrustedCertificate certificate) async {
    state = AsyncData([
      for (final c in state.value ?? const <TrustedCertificate>[])
        if (c != certificate) c,
    ]);
    return const Ok(null);
  }

  @override
  Future<Result<void>> forgetAll() async {
    state = const AsyncData([]);
    return const Ok(null);
  }
}

void main() {
  group('LocalTrustedCertificateRepository', () {
    late Directory dir;
    late LocalTrustedCertificateRepository repository;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('trusted_certs_');
      repository = LocalTrustedCertificateRepository(
        TrustedCertificateStore(
          file: () async => File('${dir.path}/sub/trusted.json'),
        ),
      );
    });
    tearDown(() => dir.deleteSync(recursive: true));

    Future<List<TrustedCertificate>> all() async =>
        (await repository.all()).valueOrNull!;

    test('trusts nothing until told', () async {
      expect(await all(), isEmpty);
    });

    test('trust is for the site, and answers with the new list', () async {
      final after = await repository.trust(_site, _expired);
      expect(after.valueOrNull, [
        const TrustedCertificate(origin: _site, error: _expired),
      ]);
      expect(await all(), after.valueOrNull);
    });

    test(
      'trusting a site again keeps one entry, with the latest error',
      () async {
        await repository.trust(_site, _expired);
        await repository.trust(_site, 'net::ERR_CERT_AUTHORITY_INVALID');

        final items = await all();
        expect(items.length, 1);
        expect(items.single.error, 'net::ERR_CERT_AUTHORITY_INVALID');
      },
    );

    test('trusting twice keeps one entry; forgetting removes it', () async {
      await repository.trust(_site, _expired);
      await repository.trust(_site, _expired);
      expect((await all()).length, 1);

      await repository.forget(
        const TrustedCertificate(origin: _site, error: _expired),
      );
      expect(await all(), isEmpty);
    });

    test('forget all, and writes at once lose none', () async {
      await Future.wait([
        repository.trust('https://a.example.com:443', _expired),
        repository.trust('https://b.example.com:443', _expired),
        repository.trust('https://c.example.com:443', _expired),
      ]);
      expect((await all()).length, 3);

      await repository.forgetAll();
      expect(await all(), isEmpty);
    });

    test('a damaged file trusts nothing', () async {
      File('${dir.path}/sub/trusted.json')
        ..createSync(recursive: true)
        ..writeAsStringSync('{not json');
      expect(await all(), isEmpty);
    });

    test('a file it cannot write is a StorageFailure, not a throw', () async {
      // A directory where the file should be: writing it fails.
      Directory('${dir.path}/sub/trusted.json').createSync(recursive: true);
      final result = await repository.trust(_site, _expired);
      expect(result.failureOrNull, isA<StorageFailure>());
    });
  });

  group('CertificateProblem', () {
    test('names the common problems and the rest as other', () {
      expect(CertificateProblem.of(_expired), CertificateProblem.dates);
      expect(
        CertificateProblem.of('net::ERR_CERT_COMMON_NAME_INVALID'),
        CertificateProblem.name,
      );
      expect(
        CertificateProblem.of('net::ERR_CERT_AUTHORITY_INVALID'),
        CertificateProblem.authority,
      );
      expect(
        CertificateProblem.of('net::ERR_CERT_REVOKED'),
        CertificateProblem.other,
      );
    });

    test('only certificate errors count, not an offline page', () {
      expect(CertificateProblem.isCertificateError(_expired), isTrue);
      expect(
        CertificateProblem.isCertificateError('net::ERR_INTERNET_DISCONNECTED'),
        isFalse,
      );
      expect(CertificateProblem.isCertificateError(''), isFalse);
    });
  });

  group('MiniAppCertificateGuard.originOf', () {
    test('spells the port out and only takes secure addresses', () {
      String? of(String url) =>
          MiniAppCertificateGuard.originOf(Uri.tryParse(url));
      expect(of('https://zentao.example.com:4433/zentao/my.html'), _site);
      expect(
        of('https://zentao.example.com/x'),
        'https://zentao.example.com:443',
      );
      expect(of('http://zentao.example.com/x'), isNull);
      expect(of('chrome-error://chromewebdata/'), isNull);
      expect(MiniAppCertificateGuard.originOf(null), isNull);
    });
  });

  group('MiniAppTrustedCertificatesSection', () {
    Widget app(List<TrustedCertificate> initial) => ProviderScope(
      overrides: [
        trustedCertificatesProvider.overrideWith(
          () => _FakeController(initial),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        theme: buildAppTheme(
          variant: AppThemeVariant.light,
          surface: SurfaceStyle.outline,
          density: AppDensity.comfortable,
        ),
        home: const Scaffold(body: MiniAppTrustedCertificatesSection()),
      ),
    );

    testWidgets('says when no site is trusted', (tester) async {
      await tester.pumpWidget(app(const []));
      await tester.pumpAndSettle();
      expect(find.text('No site is trusted.'), findsOneWidget);
    });

    testWidgets('lists each site with why, and forgets one', (tester) async {
      await tester.pumpWidget(
        app(const [
          TrustedCertificate(origin: _site, error: _expired),
          TrustedCertificate(
            origin: 'https://other.example.com:443',
            error: 'net::ERR_CERT_AUTHORITY_INVALID',
          ),
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.text(_site), findsOneWidget);
      expect(find.text('has expired, or is not valid yet'), findsOneWidget);
      expect(find.text('Forget all'), findsOneWidget);

      await tester.tap(find.text('Forget').first);
      await tester.pumpAndSettle();
      expect(find.text(_site), findsNothing);
      expect(find.text('https://other.example.com:443'), findsOneWidget);
    });
  });
}
