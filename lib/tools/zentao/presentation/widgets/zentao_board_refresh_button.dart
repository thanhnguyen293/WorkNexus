import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/board/presentation/widgets/board_refresh_button.dart';
import '../providers/zentao_bug_streams.dart';
import '../providers/zentao_task_streams.dart';

/// Refresh for the bug board ([bugs]) or the task board: starts every
/// column's view over from its first page.
class ZenTaoBoardRefreshButton extends ConsumerWidget {
  const ZenTaoBoardRefreshButton({super.key, required this.bugs});

  final bool bugs;

  @override
  Widget build(BuildContext context, WidgetRef ref) => BoardRefreshButton(
    loading: bugs
        ? ref.watch(zentaoBugSliceProvider).isLoading
        : ref.watch(zentaoTaskSliceProvider).isLoading,
    onPressed: () => ref.invalidate(
      bugs ? zentaoBugStreamsProvider : zentaoTaskStreamsProvider,
    ),
  );
}
