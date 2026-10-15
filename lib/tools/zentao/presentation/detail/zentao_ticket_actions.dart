import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/zentao_action.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/navigation/ticket_editor_route.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_context_menu.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/detail/presentation/widgets/assign_dialog.dart';
import '../../../../shared/detail/presentation/widgets/detail_action_button.dart';
import '../../domain/usecases/list_zentao_bug_actions.dart';
import '../../domain/usecases/list_zentao_create_actions.dart';
import '../../domain/usecases/list_zentao_task_actions.dart';
import '../../domain/value_objects/zentao_bug_action.dart';
import '../../domain/value_objects/zentao_create_action.dart';
import 'resolve_dialog.dart';
import 'zentao_action_looks.dart';
import 'zentao_bug_action_dialog.dart';
import 'zentao_task_action_dialog.dart';

/// ZenTao's own toolbar for a bug or task: Assign, a "⋯" menu, and the one
/// status action that moves the ticket on as the filled main button (see
/// `ZenTaoActionMenu.primary`). The other status actions ZenTao allows, and
/// what can be started from the ticket (a copy, a subtask, a bug), wait in
/// the menu. A story offers Assign only.
class ZenTaoActions extends ConsumerWidget {
  const ZenTaoActions({super.key, required this.ticket});
  final Ticket ticket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final kind = (ticket.externalType ?? '').toLowerCase();
    final bug = kind == 'bug' ? const ListZenTaoBugActions()(ticket) : null;
    final task = kind == 'task' ? const ListZenTaoTaskActions()(ticket) : null;
    final canAssign = bug?.canAssign ?? task?.canAssign ?? true;

    _ZenTaoItem bugItem(ZenTaoBugAction action) => (
      look: zenTaoBugActionLook(l, action),
      run: () => _open(
        context,
        action == ZenTaoBugAction.resolve
            ? ResolveDialog(ticket: ticket)
            : ZenTaoBugActionDialog(ticket: ticket, action: action),
      ),
    );
    _ZenTaoItem taskItem(ZenTaoTaskAction action) => (
      look: zenTaoTaskActionLook(l, action),
      run: () => _open(
        context,
        ZenTaoTaskActionDialog(ticket: ticket, action: action),
      ),
    );

    final primary = switch ((bug?.primary, task?.primary)) {
      (final b?, _) => bugItem(b),
      (_, final t?) => taskItem(t),
      _ => null,
    };
    final more = <_ZenTaoItem>[
      for (final a in bug?.actions ?? const <ZenTaoBugAction>[])
        if (a != bug?.primary) bugItem(a),
      for (final a in task?.actions ?? const <ZenTaoTaskAction>[])
        if (a != task?.primary) taskItem(a),
      for (final action in const ListZenTaoCreateActions()(ticket))
        (
          look: zenTaoCreateActionLook(l, action),
          // The editor takes the screen; the new one opens on save.
          run: () => ref
              .read(appNavProvider.notifier)
              .openEditor(_editorRoute(action, ticket)),
        ),
    ];

    return Wrap(
      spacing: context.spacing.md,
      runSpacing: context.spacing.md,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (canAssign)
          DetailActionButton(
            icon: LucideIcons.userPlus300,
            label: l.assign,
            onTap: () => _open(context, AssignDialog(ticket: ticket)),
          ),
        if (kind == 'task')
          DetailActionButton(
            icon: LucideIcons.copy300,
            label: l.zentaoCopyTask,
            onTap: () => ref
                .read(appNavProvider.notifier)
                .openEditor(_editorRoute(ZenTaoCreateAction.copyTask, ticket)),
          ),
        if (more.isNotEmpty) _MoreActionsButton(items: more),
        if (primary != null)
          AppButton.filled(
            size: AppButtonSize.small,
            icon: primary.look.icon,
            onPressed: primary.run,
            child: Text(primary.look.label),
          ),
      ],
    );
  }
}

/// One ZenTao action: how it shows and what it does.
typedef _ZenTaoItem = ({ZenTaoActionLook look, VoidCallback run});

/// The "⋯" button holding the actions that are not the main one.
class _MoreActionsButton extends StatelessWidget {
  const _MoreActionsButton({required this.items});

  final List<_ZenTaoItem> items;

  @override
  Widget build(BuildContext context) {
    return AppIconButton(
      outlined: true,
      icon: LucideIcons.ellipsis300,
      tooltip: AppL10n.of(context).more,
      onPressed: () => _show(context),
    );
  }

  Future<void> _show(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final at =
        box?.localToGlobal(Offset(0, box.size.height + context.spacing.xs)) ??
        Offset.zero;
    final picked = await showAppContextMenu(
      context,
      at: at,
      entries: [
        for (final item in items)
          AppMenuEntry(icon: item.look.icon, label: item.look.label),
      ],
    );
    if (picked != null && context.mounted) items[picked].run();
  }
}

void _open(BuildContext context, Widget dialog) =>
    showDialog<void>(context: context, builder: (_) => dialog);

/// The editor that starts [action] from [ticket].
TicketEditorRoute _editorRoute(ZenTaoCreateAction action, Ticket ticket) {
  final execution = switch (ticket.providerEntity) {
    ZenTaoTaskEntity(:final execution) => execution,
    _ => null,
  };
  return switch (action) {
    ZenTaoCreateAction.copyBug => NewBugRoute(
      accountId: ticket.accountId,
      productId: switch (ticket.providerEntity) {
        ZenTaoBugEntity(:final product?) => product,
        _ => '0',
      },
      copyOf: ticket.externalKey,
    ),
    ZenTaoCreateAction.copyTask => NewTaskRoute(
      accountId: ticket.accountId,
      executionId: execution ?? '0',
      copyOf: ticket.externalKey,
    ),
    ZenTaoCreateAction.subtask => NewTaskRoute(
      accountId: ticket.accountId,
      executionId: execution ?? '0',
      parentId: ticket.externalKey,
    ),
    ZenTaoCreateAction.bugFromTask => NewBugRoute(
      accountId: ticket.accountId,
      executionId: execution,
      taskId: ticket.externalKey,
    ),
  };
}
