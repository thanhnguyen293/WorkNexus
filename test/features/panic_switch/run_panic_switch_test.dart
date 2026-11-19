import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/panic_switch/domain/entities/app_ref.dart';
import 'package:work_nexus/features/panic_switch/domain/entities/panic_switch_config.dart';
import 'package:work_nexus/features/panic_switch/domain/repositories/app_switcher.dart';
import 'package:work_nexus/features/panic_switch/domain/usecases/run_panic_switch.dart';

class _MockSwitcher extends Mock implements AppSwitcher {}

void main() {
  const studio = AppRef(
    id: 'com.google.android.studio',
    name: 'Android Studio',
  );
  const slack = AppRef(id: 'com.tinyspeck.slackmacgap', name: 'Slack');
  late _MockSwitcher apps;

  setUpAll(() {
    registerFallbackValue(studio);
    registerFallbackValue(<AppRef>[]);
  });

  setUp(() {
    apps = _MockSwitcher();
    when(() => apps.activate(any())).thenAnswer((_) async => const Ok(null));
    when(() => apps.hideOthers(any())).thenAnswer((_) async => const Ok(null));
    when(() => apps.hideSelf()).thenAnswer((_) async => const Ok(null));
  });

  test(
    'hides all but the apps to open, opens them first-on-top, then itself',
    () async {
      final result = await RunPanicSwitch(apps)(
        const PanicSwitchConfig(appsToOpen: [studio, slack]),
      );

      expect(result.isOk, isTrue);
      verifyInOrder([
        () => apps.hideOthers([studio, slack]),
        () => apps.activate(slack),
        () => apps.activate(studio),
        () => apps.hideSelf(),
      ]);
    },
  );

  test('with no app to open, still hides everything else', () async {
    await RunPanicSwitch(apps)(const PanicSwitchConfig());
    verify(() => apps.hideOthers([])).called(1);
    verifyNever(() => apps.activate(any()));
  });

  test('keeps going after a failure and returns it', () async {
    when(
      () => apps.activate(any()),
    ).thenAnswer((_) async => const Err(UnexpectedFailure('no')));

    final result = await RunPanicSwitch(apps)(
      const PanicSwitchConfig(appsToOpen: [studio]),
    );

    expect(result.failureOrNull, isA<UnexpectedFailure>());
    verify(() => apps.hideOthers([studio])).called(1);
    verify(() => apps.hideSelf()).called(1);
  });
}
