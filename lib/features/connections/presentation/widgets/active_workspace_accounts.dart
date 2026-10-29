import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/navigation/navigation_providers.dart';
import 'account_list.dart';

/// The active workspace's connected accounts, each managed in place (sync,
/// edit, remove), under the workspace heading (edit, delete).
class ActiveWorkspaceAccounts extends ConsumerWidget {
  const ActiveWorkspaceAccounts({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(activeWorkspaceProvider);
    if (workspace == null) return const SizedBox.shrink();
    return WorkspaceAccounts(
      workspaceId: workspace.id,
      lookups: ref.watch(lookupsProvider),
    );
  }
}
