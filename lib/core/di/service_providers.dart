import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/sync/data/sync_service.dart';
import '../domain/adapters/source_sync_service.dart';
import '../domain/adapters/ticket_detail_service.dart';
import '../domain/adapters/zentao_bug_service.dart';
import 'service_locator.dart';

// The data layer's SyncService, handed to presentation only as domain ports
// (rules 1.3, 8.2): features watch these providers and never import the
// implementation. Part of the composition root, so it may know both sides.
// Each reads the locator lazily, so tests can register a fake SyncService.

final sourceSyncServiceProvider = Provider<SourceSyncService>(
  (ref) => getIt<SyncService>(),
);

final ticketDetailServiceProvider = Provider<TicketDetailService>(
  (ref) => getIt<SyncService>(),
);

final zenTaoBugServiceProvider = Provider<ZenTaoBugService>(
  (ref) => getIt<SyncService>(),
);
