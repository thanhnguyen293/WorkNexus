import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/navigation/mini_app_links.dart';
import 'package:work_nexus/features/mini_apps/domain/entities/mini_app.dart';
import 'package:work_nexus/features/mini_apps/presentation/providers/mini_app_browser_controller.dart';
import 'package:work_nexus/features/mini_apps/presentation/providers/mini_app_providers.dart';

const _app = MiniApp(
  id: 'a',
  name: 'A',
  url: 'https://a.io',
  lastUrl: 'https://a.io/last',
  position: 0,
);

Future<ProviderContainer> _container(List<MiniApp> apps) async {
  final container = ProviderContainer(
    overrides: [miniAppsProvider.overrideWith((ref) => Stream.value(apps))],
  );
  addTearDown(container.dispose);
  // Riverpod pauses a provider nobody listens to.
  container.listen(miniAppsProvider, (_, _) {});
  await container.read(miniAppsProvider.future);
  return container;
}

void main() {
  test('opens on the page the app was last on', () async {
    final container = await _container([_app]);
    expect(
      container.read(miniAppBrowserProvider('a')).initialUrl,
      'https://a.io/last',
    );
    expect(
      container.read(miniAppBrowserProvider('a')).address,
      'https://a.io/last',
    );
  });

  test('opens on its own address when it was never left elsewhere', () async {
    final container = await _container([_app.copyWith(lastUrl: null)]);
    expect(
      container.read(miniAppBrowserProvider('a')).initialUrl,
      'https://a.io',
    );
  });

  test('a link that opened the app wins over the last page', () async {
    final container = await _container([_app]);
    container.read(miniAppNavigationProvider.notifier).state =
        const MiniAppNavigation(id: 'a', url: 'https://a.io/ticket', seq: 1);
    expect(
      container.read(miniAppBrowserProvider('a')).initialUrl,
      'https://a.io/ticket',
    );
  });

  test(
    'a link is used once: reopened later, the app is back where it was',
    () async {
      final container = await _container([_app]);
      container.read(miniAppNavigationProvider.notifier).state =
          const MiniAppNavigation(id: 'a', url: 'https://a.io/ticket', seq: 1);
      // The open view keeps the app's browser alive.
      final view = container.listen(miniAppBrowserProvider('a'), (_, _) {});
      await Future<void>.delayed(Duration.zero);
      expect(container.read(miniAppNavigationProvider), isNull);
      // Closed to save memory: the view goes, and the browser with it.
      view.close();
      await Future<void>.delayed(Duration.zero);
      expect(container.exists(miniAppBrowserProvider('a')), isFalse);
      expect(
        container.read(miniAppBrowserProvider('a')).initialUrl,
        'https://a.io/last',
      );
    },
  );

  test('a link aimed at another app is not its own', () async {
    final container = await _container([_app]);
    container.read(miniAppNavigationProvider.notifier).state =
        const MiniAppNavigation(id: 'b', url: 'https://b.io/x', seq: 1);
    expect(
      container.read(miniAppBrowserProvider('a')).initialUrl,
      'https://a.io/last',
    );
  });

  test(
    'progress and errors show in the state, and a new load clears the error',
    () async {
      final container = await _container([_app]);
      final browser = container.read(miniAppBrowserProvider('a').notifier);
      browser.onProgress(0.4);
      expect(container.read(miniAppBrowserProvider('a')).loading, isTrue);
      browser.onError('net::ERR_FAILED');
      expect(
        container.read(miniAppBrowserProvider('a')).loadError,
        'net::ERR_FAILED',
      );
      browser.onLoadStart();
      browser.onProgress(1);
      final state = container.read(miniAppBrowserProvider('a'));
      expect(state.loadError, isNull);
      expect(state.loading, isFalse);
    },
  );

  test('back and forward do nothing while there is nowhere to go', () async {
    final container = await _container([_app]);
    final browser = container.read(miniAppBrowserProvider('a').notifier);
    // No web view is attached: these must not throw.
    browser
      ..goBack()
      ..goForward()
      ..reload()
      ..stop();
  });
}
