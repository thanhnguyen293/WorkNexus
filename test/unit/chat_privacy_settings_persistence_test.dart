import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/data/mappers/mappers.dart';
import 'package:work_nexus/core/database/database.dart';
import 'package:work_nexus/core/settings/app_settings.dart';
import 'package:work_nexus/core/settings/chat_privacy.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<ChatPrivacy> roundTrip(ChatPrivacy privacy) async {
    await db.saveSettings(
      appSettingsToCompanion(AppSettings(chatPrivacy: privacy)),
    );
    return appSettingsFromRow((await db.getSettings())!).chatPrivacy;
  }

  test('a fresh install starts with the mode off, every part picked', () {
    expect(const AppSettings().chatPrivacy, const ChatPrivacy());
    expect(const ChatPrivacy().enabled, isFalse);
  });

  test('the mode and the parts it blurs survive a restart', () async {
    const privacy = ChatPrivacy(
      enabled: true,
      hidePreviews: false,
      hideMessages: false,
    );
    expect(await roundTrip(privacy), privacy);
    expect(await roundTrip(const ChatPrivacy()), const ChatPrivacy());
  });
}
