import 'package:drift/native.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/database/database.dart';
import 'package:work_nexus/core/domain/entities/account.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/entities/workspace.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/settings/app_settings.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/fonts.dart';
import 'package:work_nexus/data/local/database_seeder.dart';
import 'package:work_nexus/data/local/mappers.dart';
import 'package:work_nexus/data/local/repositories/local_ticket_repository.dart';
import 'package:work_nexus/features/translation/data/repositories/local_translation_repository.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('seeds the database from the design data on first run', () async {
    expect(await db.countTickets(), 0);
    await seedDatabaseIfEmpty(db, now: DateTime(2026, 7, 17, 12));
    expect(await db.countTickets(), 48);
    // Re-seeding is a no-op.
    await seedDatabaseIfEmpty(db, now: DateTime(2026, 7, 17, 12));
    expect(await db.countTickets(), 48);
  });

  test('watchTickets emits and re-emits after moveTicket', () async {
    await seedDatabaseIfEmpty(db, now: DateTime(2026, 7, 17, 12));
    final repo = LocalTicketRepository(db);

    final first = await repo.watchTickets().first;
    expect(first, isNotEmpty);
    final target = first.firstWhere((t) => t.status != UnifiedStatus.done);

    final emissions = <UnifiedStatus>[];
    final sub = repo
        .watchTickets()
        .map((rows) => rows.firstWhere((t) => t.id == target.id).status)
        .listen(emissions.add);

    await repo.moveTicket(target.id, UnifiedStatus.done);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();

    expect(emissions.last, UnifiedStatus.done);
    final reloaded = await repo.getTicket(target.id);
    expect(reloaded!.status, UnifiedStatus.done);
  });

  test('translations round-trip through the repository', () async {
    await seedDatabaseIfEmpty(db, now: DateTime(2026, 7, 17, 12));
    final repo = LocalTranslationRepository(db);
    // A seeded 'done' ticket has a translation record.
    final rec = await repo.getTranslation('ghP:231');
    expect(rec, isNotNull);
    expect(rec!.translatedTitle, isNotEmpty);
  });

  test(
    'purgeSeededDemoData removes demo rows but keeps real accounts',
    () async {
      await seedDatabaseIfEmpty(db, now: DateTime(2026, 7, 17, 12));
      expect(await db.countTickets(), 48);

      // A real, user-connected ZenTao account + ticket (ids that don't collide
      // with the demo ids ghP/ghA/…).
      await db
          .into(db.workspaces)
          .insert(
            workspaceToCompanion(
              const Workspace(
                id: 'ws-nexsoft-1',
                name: 'Nexsoft',
                shortCode: 'N',
                colorValue: 0xFF2F8A52,
              ),
              99,
            ),
          );
      await db
          .into(db.accounts)
          .insert(
            accountToCompanion(
              const Account(
                id: 'zt-thanh-1',
                workspaceId: 'ws-nexsoft-1',
                providerType: ProviderType.zentao,
                handle: 'Thanh',
                baseUrl: 'https://z',
                credentialsRef: 'secret:zt-thanh-1',
              ),
            ),
          );
      await db
          .into(db.tickets)
          .insert(
            ticketToCompanion(
              const Ticket(
                id: 'zt-thanh-1:4302',
                accountId: 'zt-thanh-1',
                projectId: 'zt-thanh-1:ERP',
                providerType: ProviderType.zentao,
                externalKey: '4302',
                title: 'real bug',
                body: 'x',
                priority: Priority.high,
                status: UnifiedStatus.todo,
                providerStatus: 'active',
                sourceHash: 'h',
              ),
            ),
          );

      final removed = await purgeSeededDemoData(db);
      expect(removed, 48);
      expect(await db.countTickets(), 1); // only the real ticket remains
      final accounts = await db.select(db.accounts).get();
      expect(accounts.map((a) => a.id).toList(), ['zt-thanh-1']);

      // Idempotent: a second purge removes nothing.
      expect(await purgeSeededDemoData(db), 0);
    },
  );

  test('app settings persist and reload across a fresh DB handle', () async {
    // No row yet ⇒ first-run defaults.
    expect(await db.getSettings(), isNull);

    const chosen = AppSettings(
      variant: AppThemeVariant.midnight,
      surface: SurfaceStyle.flat,
      density: AppDensity.compact,
      companyTint: true,
      locale: Locale('vi'),
      fontFamily: 'Georgia',
    );
    await db.saveSettings(appSettingsToCompanion(chosen));
    // Saving again updates the single row rather than inserting a second.
    await db.saveSettings(appSettingsToCompanion(chosen));

    final reloaded = appSettingsFromRow((await db.getSettings())!);
    expect(reloaded.variant, AppThemeVariant.midnight);
    expect(reloaded.surface, SurfaceStyle.flat);
    expect(reloaded.density, AppDensity.compact);
    expect(reloaded.companyTint, isTrue);
    expect(reloaded.locale.languageCode, 'vi');
    expect(reloaded.fontFamily, 'Georgia');
  });

  test('system font sentinel persists unchanged', () async {
    const chosen = AppSettings(fontFamily: kSystemFont);

    await db.saveSettings(appSettingsToCompanion(chosen));

    final reloaded = appSettingsFromRow((await db.getSettings())!);
    expect(reloaded.fontFamily, kSystemFont);
  });
}
