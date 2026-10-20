import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/value_objects/priority.dart';
import '../../../../core/domain/value_objects/zentao_bug_column.dart';
import '../../../../core/domain/value_objects/zentao_task_column.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/util/zentao_labels.dart';
import '../../../../shared/board/domain/usecases/derive_board_facets.dart';

/// Input for [BuildZenTaoFacetCatalog]: the bug board ([bugs]) or the task
/// board, and the [members] of its product or execution.
class ZenTaoFacetCatalogInput {
  const ZenTaoFacetCatalogInput({required this.bugs, required this.members});

  final bool bugs;
  final List<ProviderUser> members;
}

/// Every choice a ZenTao bug or task board can be filtered by, so a filter can
/// name one no loaded bug or task carries yet: all its statuses, severities,
/// priorities, bug types and resolutions, and the people of its product or
/// execution. Without [ZenTaoFacetCatalogInput.members] (not loaded, or none)
/// the people are left to what the tickets carry.
class BuildZenTaoFacetCatalog
    extends UseCase<BoardFacetCatalog, ZenTaoFacetCatalogInput> {
  const BuildZenTaoFacetCatalog();

  @override
  BoardFacetCatalog call(ZenTaoFacetCatalogInput input) {
    final members = [...input.members]
      ..sort(
        (a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );
    // Assignees are stored by login; the opener and resolver by the name the
    // person goes by (see `accountName`), so those match on that.
    final assignees = [
      for (final m in members)
        BoardFacetChoice(m.account, label: m.displayName),
      // Unassigned.
      const BoardFacetChoice(''),
    ];
    final names = [
      for (final name in {for (final m in members) m.displayName})
        BoardFacetChoice(name),
    ];
    final priorities = [
      for (final p in Priority.values) BoardFacetChoice(p.name),
    ];
    if (!input.bugs) {
      return BoardFacetCatalog({
        BoardFacetKind.status: [
          for (final c in [
            ...ZenTaoTaskColumn.values,
          ]..sort((a, b) => a.order.compareTo(b.order)))
            BoardFacetChoice(c.name),
        ],
        if (members.isNotEmpty) BoardFacetKind.assignee: assignees,
        BoardFacetKind.priority: priorities,
      });
    }
    return BoardFacetCatalog({
      BoardFacetKind.status: [
        for (final c in [
          ...ZenTaoBugColumn.values,
        ]..sort((a, b) => a.order.compareTo(b.order)))
          BoardFacetChoice(c.name),
      ],
      if (members.isNotEmpty) ...{
        BoardFacetKind.assignee: assignees,
        BoardFacetKind.resolvedBy: names,
        BoardFacetKind.openedBy: names,
      },
      BoardFacetKind.confirmed: const [
        BoardFacetChoice('1'),
        BoardFacetChoice('0'),
      ],
      BoardFacetKind.severity: [
        for (final s in const [1, 2, 3, 4]) BoardFacetChoice('$s'),
      ],
      BoardFacetKind.priority: priorities,
      BoardFacetKind.bugType: [
        for (final code in zentaoBugTypeCodes) BoardFacetChoice(code),
      ],
      BoardFacetKind.resolution: [
        for (final code in zentaoResolutionCodes) BoardFacetChoice(code),
      ],
    });
  }
}
