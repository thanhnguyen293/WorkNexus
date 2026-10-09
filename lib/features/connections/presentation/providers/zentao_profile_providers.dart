import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/zentao_department.dart';
import '../../domain/entities/zentao_profile.dart';
import '../../domain/repositories/zentao_profile_repository.dart';
import '../../domain/usecases/refresh_zentao_profile.dart';

final zenTaoProfileRepositoryProvider = Provider<ZenTaoProfileRepository>(
  (ref) => getIt<ZenTaoProfileRepository>(),
);

final zenTaoProfileProvider = StreamProvider.autoDispose
    .family<ZenTaoProfile?, String>(
      (ref, accountId) =>
          ref.watch(zenTaoProfileRepositoryProvider).watch(accountId),
    );

final zenTaoDepartmentsProvider = StreamProvider.autoDispose
    .family<List<ZenTaoDepartment>, String>(
      (ref, accountId) => ref
          .watch(zenTaoProfileRepositoryProvider)
          .watchDepartments(accountId),
    );

final refreshZenTaoProfileProvider = FutureProvider.autoDispose
    .family<Result<ZenTaoProfile>, Account>(
      (ref, account) => getIt<RefreshZenTaoProfile>()(account),
    );
