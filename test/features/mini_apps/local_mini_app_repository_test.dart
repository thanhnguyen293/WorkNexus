import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/database/database.dart';
import 'package:work_nexus/features/mini_apps/data/datasources/favicon_fetcher.dart';
import 'package:work_nexus/features/mini_apps/data/datasources/mini_app_icon_storage.dart';
import 'package:work_nexus/features/mini_apps/data/datasources/mini_app_local_datasource.dart';
import 'package:work_nexus/features/mini_apps/data/repositories/local_mini_app_repository.dart';
import 'package:work_nexus/features/mini_apps/domain/entities/mini_app.dart';

void main() {
  test('watchAll emits again when an app gets its icon', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = LocalMiniAppRepository(
      MiniAppLocalDatasource(db),
      MiniAppIconStorage(() async => Directory.systemTemp),
      FaviconFetcher(),
    );
    const app = MiniApp(id: 'a', name: 'A', url: 'https://a.io', position: 0);
    await repo.save(app);
    final seen = <String?>[];
    final sub = repo.watchAll().listen(
      (apps) => seen.add(apps.single.iconPath),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await repo.save(app.copyWith(iconPath: '/x.png'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();
    expect(seen, [null, '/x.png']);
  });

  test('saveOrder renumbers positions and leaves the rest alone', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = LocalMiniAppRepository(
      MiniAppLocalDatasource(db),
      MiniAppIconStorage(() async => Directory.systemTemp),
      FaviconFetcher(),
    );
    for (final (i, id) in ['a', 'b', 'c'].indexed) {
      await repo.save(
        MiniApp(id: id, name: id, url: 'https://$id.io', position: i),
      );
    }
    await repo.saveLastUrl('a', 'https://a.io/x');
    await repo.saveOrder(['c', 'a', 'b']);
    final apps = await repo.watchAll().first;
    expect([for (final a in apps) a.id], ['c', 'a', 'b']);
    expect([for (final a in apps) a.position], [0, 1, 2]);
    expect(apps[1].lastUrl, 'https://a.io/x');
  });
}
