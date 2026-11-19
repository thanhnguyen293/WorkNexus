import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/database/app_settings_kv_store.dart';
import 'package:work_nexus/core/database/database.dart';
import 'package:work_nexus/features/panic_switch/data/datasources/panic_switch_settings_store.dart';
import 'package:work_nexus/features/panic_switch/data/mappers/panic_switch_config_mapper.dart';
import 'package:work_nexus/features/panic_switch/data/repositories/local_panic_switch_config_repository.dart';
import 'package:work_nexus/features/panic_switch/domain/entities/app_ref.dart';
import 'package:work_nexus/features/panic_switch/domain/entities/panic_switch_config.dart';

void main() {
  late AppDatabase db;
  late LocalPanicSwitchConfigRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = LocalPanicSwitchConfigRepository(
      PanicSwitchSettingsStore(AppSettingsKvStore(db)),
    );
  });

  tearDown(() => db.close());

  test('loads the defaults before anything is saved', () async {
    expect((await repository.load()).valueOrNull, const PanicSwitchConfig());
  });

  test('round-trips every field', () async {
    const config = PanicSwitchConfig(
      enabled: false,
      overlayVisible: false,
      chatGid: 'g1',
      testMode: true,
      testChatGid: 'cloud',
      testChatIsSelf: true,
      anySender: false,
      allowedSenderIds: [3, 7],
      targetApp: AppRef(
        id: 'com.google.android.studio',
        name: 'Android Studio',
      ),
      appsToHide: [AppRef(id: 'com.tinyspeck.slackmacgap', name: 'Slack')],
      hideSelf: false,
      debounceSeconds: 90,
    );

    expect((await repository.save(config)).isOk, isTrue);
    expect((await repository.load()).valueOrNull, config);
  });

  test('moves an old "send to myself" chat into test mode', () {
    final config = PanicSwitchConfigMapper.fromJson(
      '{"chatGid":"40&40","chatIsSelf":true,"debounceSeconds":60}',
    );

    expect(config.chatGid, isNull);
    expect(config.testMode, isTrue);
    expect(config.testChatGid, '40&40');
    expect(config.testChatIsSelf, isTrue);
  });

  test('keeps the listening chat of the old two-chat test mode', () {
    final config = PanicSwitchConfigMapper.fromJson(
      '{"testMode":true,"testSendChatGid":"40&40","testSendToSelf":true,'
      '"testReceiveChatGid":"g9"}',
    );

    expect(config.testChatGid, 'g9');
    expect(config.testChatIsSelf, isFalse);
  });
}
