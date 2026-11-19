import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/panic_switch_runtime.dart';

/// Runs the switch on this computer right away, with no chat involved — to
/// check the chosen apps, also while the chat server is down.
class PanicTryButton extends ConsumerWidget {
  const PanicTryButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    return AppButton.outlinedNeutral(
      icon: LucideIcons.play300,
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        final failed = l.panicSwitchTryFailed;
        final result = await ref.read(panicSwitchRuntimeProvider).runNow();
        if (result.failureOrNull case final failure?) {
          showAppSnackOn(
            messenger,
            '$failed: ${failure.message}',
            isError: true,
          );
        }
      },
      child: Text(l.panicSwitchTryButton),
    );
  }
}
