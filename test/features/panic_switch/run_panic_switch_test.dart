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

  setUpAll(() => registerFallbackValue(studio));

  setUp(() {
    apps = _MockSwitcher();
    when(() => apps.activate(any())).thenAnswer((_) async => const Ok(null));
    when(() => apps.hide(any())).thenAnswer((_) async => const Ok(null));
    when(() => apps.hideSelf()).thenAnswer((_) async => const Ok(null));
  });

  test('activates the target, hides the others, then itself', () async {
    final result = await RunPanicSwitch(apps)(
      const PanicSwitchConfig(targetApp: studio, appsToHide: [slack, studio]),
    );

    expect(result.isOk, isTrue);
    verifyInOrder([
      () => apps.activate(studio),
      () => apps.hide(slack),
      () => apps.hideSelf(),
    ]);
    verifyNever(() => apps.hide(studio));
  });

  test('keeps going after a failure and returns it', () async {
    when(
      () => apps.activate(any()),
    ).thenAnswer((_) async => const Err(UnexpectedFailure('no')));

    final result = await RunPanicSwitch(apps)(
      const PanicSwitchConfig(targetApp: studio, appsToHide: [slack]),
    );

    expect(result.failureOrNull, isA<UnexpectedFailure>());
    verify(() => apps.hide(slack)).called(1);
    verify(() => apps.hideSelf()).called(1);
  });

  test('skips hiding itself when turned off', () async {
    await RunPanicSwitch(apps)(const PanicSwitchConfig(hideSelf: false));
    verifyNever(() => apps.hideSelf());
  });
}
