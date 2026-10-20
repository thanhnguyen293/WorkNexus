import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/locator.dart';
import '../../domain/repositories/zentao_task_bugs.dart';
import '../../domain/repositories/zentao_team_members.dart';
import '../../domain/repositories/zentao_view_pages.dart';

/// Pages of ZenTao's bug and task views, written to the local database as
/// they arrive (the paged ZenTao boards).
final zentaoViewPagesProvider = Provider<ZenTaoViewPages>(
  (ref) => getIt<ZenTaoViewPages>(),
);

/// Brings a ZenTao task's related bugs into the local database.
final zentaoTaskBugsProvider = Provider<ZenTaoTaskBugs>(
  (ref) => getIt<ZenTaoTaskBugs>(),
);

/// The people of a ZenTao product or execution.
final zentaoTeamMembersProvider = Provider<ZenTaoTeamMembers>(
  (ref) => getIt<ZenTaoTeamMembers>(),
);
