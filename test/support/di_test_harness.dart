import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:injectable/injectable.dart';
import 'package:work_nexus/core/database/database.dart';
import 'package:work_nexus/core/di/service_locator.dart';
import 'package:work_nexus/data/local/database_seeder.dart';

/// Configures the GetIt service locator for the `test` environment — injectable
/// binds an in-memory drift database — and seeds it with the demo dataset by
/// default. Returns the database so the caller can close it in tearDown.
///
/// Resets the locator first so repeated `setUp` calls never hit a
/// "already registered" error. Pair every call with [resetTestLocator].
Future<AppDatabase> setUpTestLocator({bool seed = true}) async {
  await getIt.reset();
  await configureDependencies(Environment.test);
  final db = getIt<AppDatabase>();
  if (seed) await seedDatabaseIfEmpty(db);
  return db;
}

/// Tears down the locator registered by [setUpTestLocator] and closes [db].
Future<void> resetTestLocator(AppDatabase db) async {
  await getIt.reset();
  await db.close();
}

/// Unmounts the widget tree and advances time so drift's stream-query close
/// timers fire inside the test's async zone. Call at the end of a `testWidgets`
/// body that pumped a drift-backed UI; otherwise those timers linger and the
/// test fails with "A Timer is still pending" at teardown.
Future<void> disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}
