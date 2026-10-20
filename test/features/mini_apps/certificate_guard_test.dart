import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/features/mini_apps/domain/entities/trusted_certificate.dart';
import 'package:work_nexus/features/mini_apps/presentation/providers/trusted_certificates_controller.dart';
import 'package:work_nexus/features/mini_apps/presentation/util/mini_app_certificate_guard.dart';

const _trusted = 'https://intra.example.com:443';

class _MockWeb extends Mock implements InAppWebViewController {}

class _FakeController extends TrustedCertificatesController {
  @override
  Future<List<TrustedCertificate>> build() async => const [
    TrustedCertificate(origin: _trusted, error: 'net::ERR_CERT_DATE_INVALID'),
  ];
}

NavigationAction _go(String url, {bool mainFrame = true}) => NavigationAction(
  request: URLRequest(url: WebUri(url)),
  isForMainFrame: mainFrame,
);

/// The guard acts on Windows only.
final _windows = TargetPlatformVariant.only(TargetPlatform.windows);

void main() {
  late _MockWeb web;

  /// The `ignore` values sent to the web view, in order.
  late List<bool> sent;

  setUp(() {
    web = _MockWeb();
    sent = [];
    when(
      () => web.callDevToolsProtocolMethod(
        methodName: any(named: 'methodName'),
        parameters: any(named: 'parameters'),
      ),
    ).thenAnswer((call) async {
      final parameters = call.namedArguments[#parameters] as Map;
      sent.add(parameters['ignore'] as bool);
      return null;
    });
  });

  /// A guard on [web] with a widget's ref, the trusted list read.
  Future<(MiniAppCertificateGuard, ProviderContainer)> guardIn(
    WidgetTester tester,
  ) async {
    late WidgetRef widgetRef;
    late BuildContext widgetContext;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trustedCertificatesProvider.overrideWith(_FakeController.new),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            widgetRef = ref;
            widgetContext = context;
            return const SizedBox();
          },
        ),
      ),
    );
    final guard = MiniAppCertificateGuard(
      context: () => widgetContext,
      ref: widgetRef,
    )..attach(web);
    final container = ProviderScope.containerOf(widgetContext);
    await container.read(trustedCertificatesProvider.future);
    return (guard, container);
  }

  testWidgets(
    'errors are ignored for a trusted site, and stop before leaving it',
    (tester) async {
      final (guard, _) = await guardIn(tester);

      expect(
        await guard.beforeRequest(_go('https://intra.example.com/home')),
        NavigationActionPolicy.ALLOW,
      );
      expect(sent, [true]);

      // The request to the other site is let go only once errors count again.
      expect(
        await guard.beforeRequest(_go('https://evil.example.com/')),
        NavigationActionPolicy.ALLOW,
      );
      expect(sent, [true, false]);
    },
    variant: _windows,
  );

  testWidgets('a frame inside the page changes nothing', (tester) async {
    final (guard, _) = await guardIn(tester);
    await guard.beforeRequest(_go('https://intra.example.com/'));

    await guard.beforeRequest(
      _go('https://widgets.example.com/', mainFrame: false),
    );
    expect(sent, [true]);
  }, variant: _windows);

  testWidgets(
    'a site that is not trusted does not go while errors cannot be turned '
    'back on',
    (tester) async {
      final (guard, _) = await guardIn(tester);
      await guard.beforeRequest(_go('https://intra.example.com/'));
      when(
        () => web.callDevToolsProtocolMethod(
          methodName: any(named: 'methodName'),
          parameters: any(named: 'parameters'),
        ),
      ).thenThrow(Exception('web view gone'));

      expect(
        await guard.beforeRequest(_go('https://evil.example.com/')),
        NavigationActionPolicy.CANCEL,
      );
    },
    variant: _windows,
  );

  testWidgets('forgetting the site shown stops ignoring errors at once', (
    tester,
  ) async {
    final (guard, _) = await guardIn(tester);
    await guard.beforeRequest(_go('https://intra.example.com/'));

    await guard.onTrustChanged(const [
      TrustedCertificate(
        origin: 'https://other.example.com:443',
        error: 'net::ERR_CERT_DATE_INVALID',
      ),
    ]);
    expect(sent, [true, false]);

    // Nothing more to stop.
    await guard.onTrustChanged(const []);
    expect(sent, [true, false]);
  }, variant: _windows);
}
