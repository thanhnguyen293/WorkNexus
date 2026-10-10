import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/database/database.dart';
import 'package:work_nexus/core/domain/adapters/provider_adapter.dart';
import 'package:work_nexus/features/sync/data/source_list_cache.dart';

void main() {
  late AppDatabase db;
  late SourceListCache cache;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    cache = SourceListCache(db);
  });

  tearDown(() => db.close());

  test('returns null before anything was stored', () async {
    expect(await cache.readProducts('a1'), isNull);
    expect(await cache.readProjects('a1'), isNull);
  });

  test('round-trips products and projects per account, in order', () async {
    await cache.saveProducts('a1', const [
      ProviderProduct(id: '2', name: 'Daily Work Log', accountId: 'a1'),
      ProviderProduct(id: '1', name: 'VN_Socialfi', accountId: 'a1'),
    ]);
    await cache.saveProjects('a1', const [
      ProviderProject(id: 'r1', name: 'owner/repo', accountId: 'a1'),
    ]);

    final products = await cache.readProducts('a1');
    expect(products?.map((p) => (p.id, p.name, p.accountId)), [
      ('2', 'Daily Work Log', 'a1'),
      ('1', 'VN_Socialfi', 'a1'),
    ]);
    final projects = await cache.readProjects('a1');
    expect(projects?.map((p) => (p.id, p.name)), [('r1', 'owner/repo')]);
    expect(await cache.readProducts('a2'), isNull);
  });

  test('a newer save replaces the stored list', () async {
    await cache.saveProjects('a1', const [
      ProviderProject(id: 'r1', name: 'old', accountId: 'a1'),
    ]);
    await cache.saveProjects('a1', const [
      ProviderProject(id: 'r2', name: 'new', accountId: 'a1'),
    ]);

    final projects = await cache.readProjects('a1');
    expect(projects?.map((p) => p.id), ['r2']);
  });
}
