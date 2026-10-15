import 'package:drift/drift.dart';

import '../../../../core/database/database.dart';
import '../../domain/entities/mini_app.dart';

/// [MiniApp] ↔ its drift row.
abstract final class MiniAppMapper {
  static MiniApp fromRow(MiniAppRow row) => MiniApp(
    id: row.id,
    name: row.name,
    url: row.url,
    iconPath: row.iconPath,
    lastUrl: row.lastUrl,
    position: row.position,
  );

  static MiniAppsCompanion toRow(MiniApp app) => MiniAppsCompanion.insert(
    id: app.id,
    name: app.name,
    url: app.url,
    iconPath: Value(app.iconPath),
    lastUrl: Value(app.lastUrl),
    position: Value(app.position),
  );
}
