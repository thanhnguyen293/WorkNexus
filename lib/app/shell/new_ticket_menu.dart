import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/di/providers.dart';
import '../../core/domain/entities/account.dart';
import '../../core/domain/value_objects/provider_type.dart';
import '../../core/navigation/navigation_providers.dart';
import '../../core/navigation/ticket_editor_route.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_rail_button.dart';
import '../../features/board/presentation/board_providers.dart';
import '../../l10n/app_localizations.dart';

/// A new ZenTao bug or task the "+" menu offers, in [account].
typedef NewTicketChoice = ({
  Account account,
  bool isBug,
  TicketEditorRoute route,
});

/// For each ZenTao account, a new bug in the product its board shows and a new
/// task in the execution its board shows — else in the ones ZenTao has current
/// (`'0'`); either can be changed in the editor.
final newTicketChoicesProvider = Provider<List<NewTicketChoice>>((ref) {
  final accounts = ref.watch(lookupsProvider).accounts.values;
  final product = ref.watch(selectedZenTaoProductProvider);
  final execution = ref.watch(selectedZenTaoExecutionProvider);
  return [
    for (final account in accounts)
      if (account.providerType == ProviderType.zentao) ...[
        (
          account: account,
          isBug: true,
          route: NewBugRoute(
            accountId: account.id,
            productId: switch (product) {
              final p? when p.accountId == account.id => p.productId,
              _ => '0',
            },
          ),
        ),
        (
          account: account,
          isBug: false,
          route: NewTaskRoute(
            accountId: account.id,
            executionId: switch (execution) {
              final e? when e.accountId == account.id => e.executionId,
              _ => '0',
            },
          ),
        ),
      ],
  ];
});

/// The "+" menu's controller, so the keyboard shortcut can open it too.
final newTicketMenuProvider = Provider<MenuController>(
  (ref) => MenuController(),
);

/// ⌘N on macOS, Ctrl+N elsewhere.
bool get _isMac => defaultTargetPlatform == TargetPlatform.macOS;

/// The "+" rail button: a menu of the new bugs and tasks
/// [newTicketChoicesProvider] offers; hidden without a ZenTao account.
class NewTicketRailButton extends ConsumerWidget {
  const NewTicketRailButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final choices = ref.watch(newTicketChoicesProvider);
    if (choices.isEmpty) return const SizedBox.shrink();
    final severalAccounts = choices.map((c) => c.account.id).toSet().length > 1;
    final s = context.spacing;
    return MenuAnchor(
      controller: ref.watch(newTicketMenuProvider),
      // Beside the rail rather than over it.
      alignmentOffset: Offset(s.xl6 + s.sm, -s.xl6),
      menuChildren: [
        for (final choice in choices)
          MenuItemButton(
            leadingIcon: Icon(
              choice.isBug
                  ? PhosphorIconsLight.bug
                  : PhosphorIconsLight.checkSquare,
            ),
            onPressed: () => _openEditor(ref, choice.route),
            child: Text(
              severalAccounts
                  ? l.zentaoNewInAccount(
                      choice.isBug ? l.newBug : l.newTask,
                      choice.account.handle,
                    )
                  : choice.isBug
                  ? l.newBug
                  : l.newTask,
            ),
          ),
      ],
      builder: (context, menu, _) => AppRailButton(
        icon: PhosphorIconsLight.plusCircle,
        selectedIcon: PhosphorIconsFill.plusCircle,
        label: l.zentaoNewTicket(_isMac ? '⌘N' : 'Ctrl+N'),
        selected: menu.isOpen,
        onTap: () => menu.isOpen ? menu.close() : menu.open(),
      ),
    );
  }
}

/// Opens the "+" menu on ⌘N / Ctrl+N from anywhere in [child].
class NewTicketShortcut extends ConsumerWidget {
  const NewTicketShortcut({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CallbackShortcuts(
      bindings: {
        SingleActivator(
          LogicalKeyboardKey.keyN,
          meta: _isMac,
          control: !_isMac,
        ): () {
          if (ref.read(newTicketChoicesProvider).isEmpty) return;
          ref.read(newTicketMenuProvider).open();
        },
      },
      child: Focus(autofocus: true, child: child),
    );
  }
}

/// Opens the editor on [route] over whatever is showing.
void _openEditor(WidgetRef ref, TicketEditorRoute route) =>
    openTicketEditor(ref, route);
