import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/database/app_settings_kv_store.dart';
import 'package:work_nexus/core/database/database.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/chat/data/repositories/local_chat_info_panel_preference.dart';
import 'package:work_nexus/features/chat/domain/repositories/chat_info_panel_preference.dart';
import 'package:work_nexus/features/chat/presentation/providers/chat_info_panel_providers.dart';

class _MockPreference extends Mock implements ChatInfoPanelPreference {}

void main() {
  group('LocalChatInfoPanelPreference', () {
    late AppDatabase db;
    late LocalChatInfoPanelPreference preference;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      preference = LocalChatInfoPanelPreference(AppSettingsKvStore(db));
    });

    tearDown(() => db.close());

    test('shows the panel before anything is saved', () async {
      expect((await preference.isVisible()).valueOrNull, isTrue);
    });

    test('remembers hiding and showing it again', () async {
      await preference.setVisible(false);
      expect((await preference.isVisible()).valueOrNull, isFalse);

      // A new store over the same database: as after a restart.
      final reopened = LocalChatInfoPanelPreference(AppSettingsKvStore(db));
      expect((await reopened.isVisible()).valueOrNull, isFalse);

      await reopened.setVisible(true);
      expect((await preference.isVisible()).valueOrNull, isTrue);
    });
  });

  group('ChatInfoPanelVisibility', () {
    late _MockPreference preference;

    ProviderContainer container() {
      final c = ProviderContainer(
        overrides: [
          chatInfoPanelPreferenceProvider.overrideWithValue(preference),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    setUp(() => preference = _MockPreference());

    test('starts from the saved choice', () async {
      when(
        () => preference.isVisible(),
      ).thenAnswer((_) async => const Ok(false));

      expect(
        await container().read(chatInfoPanelVisibleProvider.future),
        isFalse,
      );
    });

    test('shows the panel when the choice cannot be read', () async {
      when(
        () => preference.isVisible(),
      ).thenAnswer((_) async => const Err(StorageFailure('locked')));

      expect(
        await container().read(chatInfoPanelVisibleProvider.future),
        isTrue,
      );
    });

    test('applies a change at once and saves it', () async {
      when(
        () => preference.isVisible(),
      ).thenAnswer((_) async => const Ok(true));
      when(
        () => preference.setVisible(false),
      ).thenAnswer((_) async => const Ok(null));
      final c = container();
      await c.read(chatInfoPanelVisibleProvider.future);

      final result = await c
          .read(chatInfoPanelVisibleProvider.notifier)
          .setVisible(false);

      expect(result, isA<Ok<void>>());
      expect(c.read(chatInfoPanelVisibleProvider).value, isFalse);
      verify(() => preference.setVisible(false)).called(1);
    });

    test('keeps the change for this run when saving fails', () async {
      when(
        () => preference.isVisible(),
      ).thenAnswer((_) async => const Ok(true));
      when(
        () => preference.setVisible(false),
      ).thenAnswer((_) async => const Err(StorageFailure('disk full')));
      final c = container();
      await c.read(chatInfoPanelVisibleProvider.future);

      final result = await c
          .read(chatInfoPanelVisibleProvider.notifier)
          .setVisible(false);

      expect(result, isA<Err<void>>());
      expect(c.read(chatInfoPanelVisibleProvider).value, isFalse);
    });
  });
}
