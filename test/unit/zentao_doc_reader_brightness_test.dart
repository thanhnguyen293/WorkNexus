import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
