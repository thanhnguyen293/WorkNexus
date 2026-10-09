import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../providers/zentao_profile_startup_controller.dart';

/// Starts the saved-account profile refresh when the account stream has loaded.
class ZenTaoProfileStartup extends ConsumerStatefulWidget {
  const ZenTaoProfileStartup({super.key});

  @override
  ConsumerState<ZenTaoProfileStartup> createState() =>
      _ZenTaoProfileStartupState();
}

class _ZenTaoProfileStartupState extends ConsumerState<ZenTaoProfileStartup> {
  @override
  void initState() {
    super.initState();
    ref.listenManual(accountsProvider, (previous, next) {
      final accounts = next.asData?.value;
      if (accounts != null) {
        ref
            .read(zenTaoProfileStartupControllerProvider)
            .onAccountsLoaded(accounts);
      }
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
