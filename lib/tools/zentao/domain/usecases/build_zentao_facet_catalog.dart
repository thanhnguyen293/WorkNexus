import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/value_objects/priority.dart';
import '../../../../core/domain/value_objects/zentao_bug_column.dart';
import '../../../../core/domain/value_objects/zentao_task_column.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/util/zentao_labels.dart';
import '../../../../shared/board/domain/usecases/derive_board_facets.dart';

/// Input for [BuildZenTaoFacetCatalog]: the bug board ([bugs]) or the task
/// board, the [members] of its product or execution, and the bug board
/// product's [modules] (id → path such as "Livestream/Share", in ZenTao's
/// order).
class ZenTaoFacetCatalogInput {
  const ZenTaoFacetCatalogInput({
    required this.bugs,
    required this.members,
    this.modules = const {},
  });

  final bool bugs;
  final List<ProviderUser> members;
  final Map<String, String> modules;
}

/// Every choice a ZenTao bug or task board can be filtered by, so a filter can
/// name one no loaded bug or task carries yet: all its statuses, severities,
/// priorities, bug types and resolutions, and the people of its product or
/// execution. Without [ZenTaoFacetCatalogInput.members] (not loaded, or none)
/// the people are left to what the tickets carry; without
/// [ZenTaoFacetCatalogInput.modules] the bug board has no module filter (a
/// module id alone names nothing).
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
    // ZenTao's "no module" ('0', path "/") is not a module to pick.
    final modules = [
      for (final e in input.modules.entries)
        if (e.key != '0' && e.value.trim().isNotEmpty)
          BoardFacetChoice(e.key, label: e.value),
    ];
    return BoardFacetCatalog({
      if (modules.isNotEmpty) BoardFacetKind.module: modules,
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
