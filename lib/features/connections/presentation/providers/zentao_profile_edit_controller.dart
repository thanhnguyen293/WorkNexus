import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/zentao_profile.dart';
import '../../domain/entities/zentao_profile_update.dart';
import '../../domain/usecases/update_zentao_profile.dart';

class ZenTaoProfileEditController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<Result<ZenTaoProfile>> update(
    Account account,
    ZenTaoProfileUpdate changes,
  ) => _run(() => getIt<UpdateZenTaoProfile>()(account, changes));

  Future<Result<ZenTaoProfile>> _run(
    Future<Result<ZenTaoProfile>> Function() action,
  ) async {
    state = const AsyncLoading();
    final result = await action();
    state = switch (result) {
      Ok() => const AsyncData(null),
      Err(:final failure) => AsyncError(failure, StackTrace.current),
    };
    return result;
  }
}

final zenTaoProfileEditControllerProvider =
    NotifierProvider.autoDispose<ZenTaoProfileEditController, AsyncValue<void>>(
      ZenTaoProfileEditController.new,
    );
