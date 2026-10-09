import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/zentao_action.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/navigation/ticket_editor_route.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/usecases/list_zentao_bug_actions.dart';
import '../../domain/usecases/list_zentao_create_actions.dart';
import '../../domain/usecases/list_zentao_task_actions.dart';
import '../../domain/value_objects/zentao_bug_action.dart';
import '../../domain/value_objects/zentao_create_action.dart';
import 'assign_dialog.dart';
import 'detail_action_button.dart';
import 'resolve_dialog.dart';
import 'zentao_action_looks.dart';
import 'zentao_bug_action_dialog.dart';
import 'zentao_task_action_dialog.dart';

/// ZenTao's own toolbar for a bug or task: Assign plus the status actions its
/// current state allows, each through a dialog asking what ZenTao's form for
/// it does — then what can be started from it (a copy, a subtask, a bug) in
/// the bug / task editor. A story offers Assign only.
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

    return Padding(
      padding: EdgeInsets.only(top: context.spacing.xl),
      child: Wrap(
        spacing: context.spacing.md,
        runSpacing: context.spacing.md,
        children: [
          if (canAssign)
            DetailActionButton(
              icon: PhosphorIconsLight.userPlus,
              label: l.assign,
              onTap: () => _open(context, AssignDialog(ticket: ticket)),
            ),
          for (final action in bug?.actions ?? const <ZenTaoBugAction>[])
            DetailActionButton(
              icon: zenTaoBugActionLook(l, action).icon,
              label: zenTaoBugActionLook(l, action).label,
              onTap: () => _open(
                context,
                action == ZenTaoBugAction.resolve
                    ? ResolveDialog(ticket: ticket)
                    : ZenTaoBugActionDialog(ticket: ticket, action: action),
              ),
            ),
          for (final action in task?.actions ?? const <ZenTaoTaskAction>[])
            DetailActionButton(
              icon: zenTaoTaskActionLook(l, action).icon,
              label: zenTaoTaskActionLook(l, action).label,
              onTap: () => _open(
                context,
                ZenTaoTaskActionDialog(ticket: ticket, action: action),
              ),
            ),
          for (final action in const ListZenTaoCreateActions()(ticket))
            DetailActionButton(
              icon: zenTaoCreateActionLook(l, action).icon,
              label: zenTaoCreateActionLook(l, action).label,
              onTap: () {
                // The editor takes the screen; the new one opens on save.
                openTicketEditor(ref, _editorRoute(action, ticket));
              },
            ),
        ],
      ),
    );
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
