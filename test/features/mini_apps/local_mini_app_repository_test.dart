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
}
