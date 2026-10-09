import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/util/in_flight.dart';

void main() {
  test('concurrent calls for one key share a single load', () async {
    final inFlight = InFlight<String, int>();
    final gate = Completer<int>();
    var loads = 0;
    Future<int> load() {
      loads++;
      return gate.future;
    }

    final a = inFlight.run('k', load);
    final b = inFlight.run('k', load);
    expect(identical(a, b), isTrue);
    expect(inFlight.isLoading('k'), isTrue);

    gate.complete(7);
    expect(await a, 7);
    expect(await b, 7);
    expect(loads, 1);
    expect(inFlight.isLoading('k'), isFalse);
  });

  test('different keys load independently', () async {
    final inFlight = InFlight<String, String>();
    final results = await Future.wait([
      inFlight.run('a', () async => 'A'),
      inFlight.run('b', () async => 'B'),
    ]);
    expect(results, ['A', 'B']);
  });

  test('a finished load is not reused: the next call loads again', () async {
    final inFlight = InFlight<String, int>();
    var loads = 0;
    Future<int> load() async => ++loads;

    expect(await inFlight.run('k', load), 1);
    expect(await inFlight.run('k', load), 2);
  });

  test('a failed load reaches every waiter and is then forgotten', () async {
    final inFlight = InFlight<String, int>();
    final gate = Completer<int>();
    final a = inFlight.run('k', () => gate.future);
    final b = inFlight.run('k', () => gate.future);

    gate.completeError(StateError('down'));
    await expectLater(a, throwsStateError);
    await expectLater(b, throwsStateError);
    expect(inFlight.isLoading('k'), isFalse);
    expect(await inFlight.run('k', () async => 1), 1);
  });
}
