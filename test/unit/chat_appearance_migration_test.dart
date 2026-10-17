import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/data/mappers/mappers.dart';
import 'package:work_nexus/core/database/database.dart';
import 'package:work_nexus/core/settings/app_settings.dart';
import 'package:work_nexus/core/settings/chat_appearance.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<ChatAppearance> loaded(String stored) async {
    await db.saveSettings(
      appSettingsToCompanion(
        const AppSettings(),
      ).copyWith(chatAppearance: Value(stored)),
    );
    return appSettingsFromRow((await db.getSettings())!).chatAppearance;
  }

  test('the retired Messenger style loads as ZenTao', () async {
    expect(await loaded('messenger'), ChatAppearance.zentao);
  });

  test('other styles load as they were, an unknown one as Zalo', () async {
    expect(await loaded('telegram'), ChatAppearance.telegram);
    expect(await loaded('zentao'), ChatAppearance.zentao);
    expect(await loaded('nope'), ChatAppearance.zalo);
  });
}
