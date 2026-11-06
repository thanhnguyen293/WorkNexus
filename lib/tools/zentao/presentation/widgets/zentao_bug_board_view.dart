import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/value_objects/zentao_bug_column.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/board/presentation/widgets/board_horizontal_scroll.dart';
import '../providers/zentao_board_providers.dart';
import 'zentao_bug_column_card.dart';

/// The ZenTao bug Kanban board; the table is [ZenTaoBugTableView]. Closed
/// starts folded to a strip; the user can open or fold any column.
class ZenTaoBugBoardView extends ConsumerStatefulWidget {
  const ZenTaoBugBoardView({super.key});

  @override
  ConsumerState<ZenTaoBugBoardView> createState() => _ZenTaoBugBoardViewState();
}

class _ZenTaoBugBoardViewState extends ConsumerState<ZenTaoBugBoardView> {
  /// Columns the user opened or folded against their default.
  final _toggled = <ZenTaoBugColumn>{};

  @override
  Widget build(BuildContext context) {
    final board = ref.watch(zentaoBugBoardProvider);

    return BoardHorizontalScroll(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final col in board.columns) ...[
            ZenTaoBugColumnCard(
              column: col,
              toggled: _toggled.contains(col.column),
              onToggleFold: () => setState(() {
                if (!_toggled.remove(col.column)) _toggled.add(col.column);
              }),
            ),
            SizedBox(width: context.spacing.xl),
          ],
        ],
      ),
    );
  }
}
