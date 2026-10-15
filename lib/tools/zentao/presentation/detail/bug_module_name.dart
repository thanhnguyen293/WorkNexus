import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/bug_module_names_provider.dart';

/// A bug's module by its path ("Livestream/Share"). ZenTao gives the bug only
/// the module id, so the id shows until the product's module names load, and
/// stays when they cannot.
class BugModuleName extends ConsumerWidget {
  const BugModuleName({
    super.key,
    required this.accountId,
    required this.productId,
    required this.moduleId,
  });

  final String accountId;
  final String productId;
  final String moduleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final names = ref.watch(bugModuleNamesProvider((accountId, productId)));
    return Text(
      names.value?[moduleId] ?? moduleId,
      textAlign: TextAlign.right,
      style: context.typography.secondary.copyWith(
        color: context.colors.textPrimary,
      ),
    );
  }
}
