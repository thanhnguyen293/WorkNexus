// Host-side driver for the on-device performance tests in integration_test/.
//
// Writes, under build/:
// - <key>.timeline_summary.json — frame build/raster percentiles and missed
//   frame budgets for each `traceAction` block reported by the test;
// - <key>.timeline.json — the raw timeline, loadable in DevTools/Perfetto;
// - perf_timings.json — the test's own wall-clock measurements.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    if (data == null) return;
    for (final entry in data.entries) {
      final value = entry.value;
      if (value is Map<String, dynamic> && value.containsKey('traceEvents')) {
        final summary = driver.TimelineSummary.summarize(
          driver.Timeline.fromJson(value),
        );
        await summary.writeTimelineToFile(entry.key, pretty: true);
      } else {
        await _writeJson(entry.key, value);
      }
    }
  },
);

Future<void> _writeJson(String key, Object? value) async {
  final file = File('$testOutputsDirectory/$key.json');
  await file.parent.create(recursive: true);
  await file.writeAsString(const JsonEncoder.withIndent('  ').convert(value));
}
