import 'package:flutter/material.dart';

import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/usecases/list_panic_chats.dart';

/// Picks one of [chats] (test mode's send and listen chats).
class PanicChatPicker extends StatelessWidget {
  const PanicChatPicker({
    super.key,
    required this.chats,
    required this.value,
    required this.onChanged,
  });

  final List<PanicChat> chats;

  /// The picked chat's id; null when none is.
  final String? value;
  final ValueChanged<PanicChat> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return SearchableDropdownField<PanicChat>(
      items: chats,
      value: chats.where((c) => c.chat.gid == value).firstOrNull,
      labelOf: (c) => c.title,
      hintText: l.panicSwitchGroupPick,
      searchHint: l.panicSwitchSearch,
      emptyLabel: l.panicSwitchNoMatches,
      onChanged: onChanged,
    );
  }
}
