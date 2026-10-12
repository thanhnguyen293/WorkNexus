import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/navigation/ticket_editor_route.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_context_menu.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/saved_ticket_draft.dart';
import '../providers/ticket_draft_providers.dart';
import '../util/ticket_draft_labels.dart';

/// "Drafts (n)" in a new bug's / task's editor: the other kept drafts of the
/// same kind and account, newest first; picking one hands its route to
/// [onPick]. Hidden while there is none.
class DraftPickerButton extends ConsumerStatefulWidget {
  const DraftPickerButton({
    super.key,
    required this.isBug,
    required this.accountId,
    required this.currentDraftId,
    required this.onPick,
  });

  final bool isBug;
  final String accountId;

  /// The draft being edited, left out of the list.
  final String? currentDraftId;
  final ValueChanged<TicketEditorRoute> onPick;

  @override
  ConsumerState<DraftPickerButton> createState() => _DraftPickerButtonState();
}

class _DraftPickerButtonState extends ConsumerState<DraftPickerButton> {
  final _menu = MenuController();

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final s = context.spacing;
    final dateFormat = ref.watch(
      appSettingsProvider.select((s) => s.dateFormat),
    );
    final drafts = [
      for (final d
          in ref.watch(ticketDraftsProvider).value ??
              const <SavedTicketDraft>[])
        if (d.accountId == widget.accountId &&
            d.id != widget.currentDraftId &&
            (d is SavedBugDraft) == widget.isBug)
          d,
    ];
    if (drafts.isEmpty) return const SizedBox.shrink();
    return MenuAnchor(
      controller: _menu,
      alignmentOffset: Offset(0, s.xs),
      style: appMenuAnchorStyle,
      menuChildren: [
        AppMenuPanel(
          entries: [
            for (final d in drafts)
              AppMenuEntry(
                icon: LucideIcons.fileText300,
                label: draftLabel(context, d, dateFormat: dateFormat),
              ),
          ],
          onSelected: (i) {
            _menu.close();
            widget.onPick(draftRoute(drafts[i]));
          },
        ),
      ],
      builder: (context, menu, _) => AppButton.textNeutral(
        size: AppButtonSize.small,
        icon: LucideIcons.fileClock300,
        onPressed: () => menu.isOpen ? menu.close() : menu.open(),
        child: Text(l.ticketDrafts(drafts.length)),
      ),
    );
  }
}
