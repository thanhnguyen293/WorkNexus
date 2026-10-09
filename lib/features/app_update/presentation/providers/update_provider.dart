import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../domain/repositories/update_repository.dart';

/// The version of the running build, for the settings card and bug reports.
final appVersionProvider = FutureProvider<String>(
  (ref) => getIt<UpdateRepository>().currentVersion(),
);
