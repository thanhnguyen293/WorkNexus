import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
        showDialog<void>(
          context: context,
          // Closing it by a stray click mid-download would drop the controller
          // while the install runs on.
          barrierDismissible: false,
          builder: (_) => UpdateDialog(update: update),
        );
      });
    });
    return child;
  }
}
