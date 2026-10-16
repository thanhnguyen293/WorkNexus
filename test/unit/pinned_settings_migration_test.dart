import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/data/mappers/mappers.dart';
import 'package:work_nexus/core/database/database.dart';
import 'package:work_nexus/core/settings/app_settings.dart';

/// Saves a settings row whose pins are as older builds wrote them: product
/// and repo pins as bare `accountId:id` keys, executions — and, from one
/// build, ZenTao project pins (`zentao-project:…`, executions carrying a
/// `parentKey`).
Future<AppSettings> _load(
  AppDatabase db, {
  required String projects,
  required String executions,
}) async {
  await db.saveSettings(
    appSettingsToCompanion(const AppSettings()).copyWith(
      pinnedProjectsJson: Value(projects),
      pinnedExecutionsJson: Value(executions),
    ),
  );
  return appSettingsFromRow((await db.getSettings())!);
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test(
    'product and repo pins load as they were; project pins are dropped',
    () async {
      final s = await _load(
        db,
        projects: '["zt:12","gl-a:77","zentao-project:zt:30"]',
        executions:
            '[{"accountId":"zt","projectId":"30","executionId":"e1",'
            '"name":"S1","parentKey":"zentao-project:zt:30"}]',
      );

      expect(s.pinnedProjects, {'zt:12', 'gl-a:77'});
      expect(s.pinnedExecutions.single.key, 'zt:e1');
      expect(s.pinnedExecutions.single.name, 'S1');
    },
  );

  test('saved again, the dropped project pins are gone', () async {
    final s = await _load(
      db,
      projects: '["zentao-project:zt:30","zt:12"]',
      executions: '[]',
    );

    expect(
      appSettingsToCompanion(s).pinnedProjectsJson.value,
      isNot(contains('zentao-project:')),
    );
  });
}
