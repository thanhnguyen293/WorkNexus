import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../providers/update_provider.dart';
import 'update_dialog.dart';

class UpdateNotificationListener extends ConsumerWidget {
  const UpdateNotificationListener({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(updateCheckProvider, (previous, next) {
      final update = next.asData?.value.valueOrNull;
      if (update == null) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        final l10n = AppL10n.of(context);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(l10n.updateAvailable(update.latestVersion)),
              duration: const Duration(seconds: 12),
              action: SnackBarAction(
                label: l10n.updateAction,
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => UpdateDialog(update: update),
                ),
              ),
            ),
          );
      });
    });
    return child;
  }
}
