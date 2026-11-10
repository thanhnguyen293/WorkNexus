import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/settings/app_settings.dart';
import 'package:work_nexus/tools/zentao/presentation/providers/zentao_doc_providers.dart';

void main() {
  late ProviderContainer container;
  ZenTaoDocReaderBrightness notifier() =>
      container.read(zentaoDocReaderBrightnessProvider.notifier);
  Brightness? forced() => container.read(zentaoDocReaderBrightnessProvider);

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  test('follows the app until switched', () {
    expect(forced(), isNull);
  });

  test('switching a dark app reads on light, switching back follows', () {
    notifier().toggle(current: Brightness.dark, app: Brightness.dark);
    expect(forced(), Brightness.light);

    notifier().toggle(current: Brightness.light, app: Brightness.dark);
    expect(forced(), isNull);
  });

  test('switching a light app reads on dark', () {
    notifier().toggle(current: Brightness.light, app: Brightness.light);
    expect(forced(), Brightness.dark);
  });

  test('the choice is saved to the settings and read back on start', () {
    AppSettings? saved;
    final c = ProviderContainer(
      overrides: [settingsPersistProvider.overrideWithValue((s) => saved = s)],
    );
    addTearDown(c.dispose);
    c
        .read(zentaoDocReaderBrightnessProvider.notifier)
        .toggle(current: Brightness.dark, app: Brightness.dark);
    expect(saved?.docsReaderBrightness, Brightness.light);

    // A restart seeds the settings with what was saved.
    final restarted = ProviderContainer(
      overrides: [initialAppSettingsProvider.overrideWithValue(saved!)],
    );
    addTearDown(restarted.dispose);
    expect(restarted.read(zentaoDocReaderBrightnessProvider), Brightness.light);
  });

  test('the open document is kept per account', () {
    container.read(zentaoOpenDocProvider.notifier)
      ..open('a1', '247', '115')
      ..open('a2', '89', '50')
      ..open('a1', '89', '59');
    expect(container.read(zentaoOpenDocProvider), {
      'a1': (libId: '89', docId: '59'),
      'a2': (libId: '89', docId: '50'),
    });
  });

  test('the tree filter is kept per account', () {
    container.read(zentaoDocFilterProvider.notifier).set('a1', 'wal');
    expect(container.read(zentaoDocFilterProvider)['a1'], 'wal');
    expect(container.read(zentaoDocFilterProvider)['a2'], isNull);
  });
}
