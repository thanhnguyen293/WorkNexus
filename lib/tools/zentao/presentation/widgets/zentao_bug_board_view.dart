import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/board/presentation/widgets/board_horizontal_scroll.dart';
import '../providers/zentao_board_providers.dart';
import 'zentao_bug_column_card.dart';

/// The ZenTao bug Kanban board; the table is [ZenTaoBugTableView].
class ZenTaoBugBoardView extends ConsumerWidget {
  const ZenTaoBugBoardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(zentaoBugBoardProvider);

    return BoardHorizontalScroll(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final col in board.columns) ...[
            ZenTaoBugColumnCard(column: col),
            SizedBox(width: context.spacing.xl),
          ],
        ],
      ),
    );
  }
}
