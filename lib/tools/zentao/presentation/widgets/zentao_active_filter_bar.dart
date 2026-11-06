import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/board/presentation/widgets/active_filter_bar.dart';
import '../providers/zentao_facet_catalog_provider.dart';
import 'zentao_status_filter_option.dart';

/// The filters in effect on a ZenTao board, named as its Filters popover
/// names them (statuses as its columns, people and modules by name).
class ZenTaoActiveFilterBar extends ConsumerWidget {
  const ZenTaoActiveFilterBar({super.key, required this.bugs});

  /// The bug board, else the task board.
  final bool bugs;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ActiveFilterBar(
    catalog: ref.watch(zentaoFacetCatalogProvider(bugs)),
    statusOption: zentaoStatusFilterOption(bugBoard: bugs),
  );
}
