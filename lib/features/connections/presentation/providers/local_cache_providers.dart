import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../domain/usecases/clear_local_cache.dart';

final clearLocalCacheProvider = Provider<ClearLocalCache>(
  (ref) => getIt<ClearLocalCache>(),
);
