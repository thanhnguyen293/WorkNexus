import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/util/load_speed_meter.dart';

void main() {
  final t0 = DateTime(2026, 11, 6, 10);
  DateTime at(int ms) => t0.add(Duration(milliseconds: ms));

  test('no speed until two samples are apart', () {
    final meter = LoadSpeedMeter();
    expect(meter.bytesPerSecond, isNull);
    meter.add(at(0), 1000);
    expect(meter.bytesPerSecond, isNull);
  });

  test('bytes gained over time give the speed', () {
    final meter = LoadSpeedMeter()
      ..add(at(0), 0)
      ..add(at(500), 500000)
      ..add(at(1000), 1000000);

    expect(meter.bytesPerSecond, 1000000);
  });

  test('only the last window counts', () {
    final meter = LoadSpeedMeter(window: const Duration(seconds: 1))
      // A fast start…
      ..add(at(0), 0)
      ..add(at(500), 4000000)
      // …then a steady 1 MB/s.
      ..add(at(1500), 5000000)
      ..add(at(2500), 6000000);

    expect(meter.bytesPerSecond, 1000000);
  });

  test('a buffer that restarts lower (a seek) starts a new run', () {
    final meter = LoadSpeedMeter()
      ..add(at(0), 0)
      ..add(at(1000), 8000000)
      ..add(at(1500), 2000000);

    expect(meter.bytesPerSecond, isNull);
    meter.add(at(2500), 2500000);
    expect(meter.bytesPerSecond, 500000);
  });
}
