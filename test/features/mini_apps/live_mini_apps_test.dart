import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/mini_apps/presentation/util/live_mini_apps.dart';

void main() {
  const all = {'a', 'b', 'c', 'd'};

  test('moves the current app to the most recent end', () {
    expect(
      liveMiniApps(live: ['a', 'b'], current: 'a', existing: all, max: 3),
      ['b', 'a'],
    );
  });

  test('closes the app left longest ago once past the limit', () {
    expect(
      liveMiniApps(live: ['a', 'b', 'c'], current: 'd', existing: all, max: 3),
      ['b', 'c', 'd'],
    );
  });

  test('drops removed apps and keeps the rest without a current one', () {
    expect(
      liveMiniApps(
        live: ['a', 'b', 'c'],
        current: null,
        existing: {'a', 'c'},
        max: 3,
      ),
      ['a', 'c'],
    );
  });
}
