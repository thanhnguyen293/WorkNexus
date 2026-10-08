import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../board_providers.dart';
import 'board_horizontal_scroll.dart';
import 'zentao_bug_column_card.dart';

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
