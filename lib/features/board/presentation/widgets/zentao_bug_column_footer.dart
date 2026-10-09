import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/badges.dart';
import '../../../../core/widgets/inline_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/zentao_bug_column.dart';
import '../../domain/value_objects/zentao_bug_stream.dart';
import '../board_providers.dart';

/// The end of a bug column whose view has more pages. The list only builds it
/// once it scrolls into reach, so building it is what loads the next page —
/// again and again while the column stays short — showing card skeletons
/// meanwhile; a failed page offers a retry instead.
class ZenTaoBugColumnFooter extends ConsumerWidget {
  const ZenTaoBugColumnFooter({
    super.key,
    required this.column,
    this.empty = false,
  });

  final ZenTaoBugColumn column;

  /// Whether the column has no cards yet: it then shows more skeletons, as
  /// the board's own loading skeleton does.
  final bool empty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream = ref.watch(zentaoBugColumnStreamProvider(column));
    final controller = ref.read(zentaoBugStreamsProvider.notifier);
    final view = ZenTaoBugStream.of(column);
    if (stream.failure != null) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: context.spacing.sm),
        child: Column(
          children: [
            AppInlineNote(
              text: AppL10n.of(context).bugTabLoadFailed,
              isError: true,
            ),
            TextButton(
              onPressed: () => controller.retry(view),
              child: Text(AppL10n.of(context).retry),
            ),
          ],
        ),
      );
    }
    if (stream.canLoadMore) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => controller.loadMore(view),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < (empty ? 3 : 2); i++) ...[
          if (i > 0) SizedBox(height: context.spacing.md),
          SkeletonBox(
            width: double.infinity,
            height: 78,
            radius: context.radii.sm,
          ),
        ],
      ],
    );
  }
}
