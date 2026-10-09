import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/available_update.dart';
import '../../domain/repositories/update_repository.dart';
import '../../domain/usecases/check_for_update.dart';

final updateCheckProvider =
    FutureProvider.autoDispose<Result<AvailableUpdate?>>((ref) {
      return getIt<CheckForUpdate>()();
    });

/// The version of the running build, for the settings card and bug reports.
final appVersionProvider = FutureProvider<String>(
  (ref) => getIt<UpdateRepository>().currentVersion(),
);
