import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/debug/app_talker.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/error/result.dart';
import '../../domain/usecases/refresh_zentao_profile.dart';

final zenTaoProfileStartupControllerProvider =
    Provider<ZenTaoProfileStartupController>(
      (ref) => ZenTaoProfileStartupController(getIt<RefreshZenTaoProfile>()),
    );

/// Refreshes profiles for saved ZenTao connections once when they first load.
class ZenTaoProfileStartupController {
  ZenTaoProfileStartupController(this._refresh);

  final RefreshZenTaoProfile _refresh;
  bool _started = false;

  void onAccountsLoaded(List<Account> accounts) {
    if (_started) return;
    _started = true;
    unawaited(_refreshSavedAccounts(accounts));
  }

  Future<void> _refreshSavedAccounts(List<Account> accounts) async {
    for (final account in accounts) {
      if (account.providerType != ProviderType.zentao ||
          account.credentialsRef == null ||
          account.baseUrl == null) {
        continue;
      }
      try {
        if (await _refresh(account) case Err(:final failure)) {
          appTalker.warning(
            'ZenTao GET /user failed for ${account.handle}: ${failure.message}',
          );
        }
      } catch (error, stackTrace) {
        appTalker.handle(
          error,
          stackTrace,
          'ZenTao GET /user failed for ${account.handle}',
        );
      }
    }
  }
}
