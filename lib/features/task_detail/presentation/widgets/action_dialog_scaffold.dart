import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dialog_frame.dart';
import '../../../../core/widgets/app_input_decoration.dart';
import '../../../../core/widgets/inline_status.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../sync/data/sync_service.dart';
import 'section_label.dart';

/// Users the ticket can be (re)assigned to, fetched from its provider.
final providerUsersProvider = FutureProvider.family<List<ProviderUser>, String>(
  (ref, ticketId) async {
    final ticket = ref.read(ticketByIdProvider(ticketId));
    if (ticket == null) return const [];
    final res = await getIt<SyncService>().listUsers(ticket);
    return res.fold((v) => v, (_) => const <ProviderUser>[]);
  },
);

/// Shared chrome for the ticket action dialogs (Assign / Resolve / Reviewers /
/// ZenTao actions): the app dialog frame with Cancel + the submit action.
class ActionScaffold extends StatelessWidget {
  const ActionScaffold({
    super.key,
    required this.title,
    required this.child,
    required this.submitLabel,
    required this.onSubmit,
    required this.busy,
    this.canSubmit = true,
    this.icon,
  });

  final String title;
  final Widget child;
  final String submitLabel;
  final VoidCallback onSubmit;
  final bool busy;
  final bool canSubmit;

  /// The action's glyph, shown before the title.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final s = context.spacing;
    return AppDialogFrame(
      title: title,
      leadingIcon: icon,
      maxWidth: context.sizes.dialogMd,
      actions: [
        const Spacer(),
        AppButton.textNeutral(
          onPressed: busy ? null : () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        AppButton.filled(
          isLoading: busy,
          onPressed: (busy || !canSubmit) ? null : onSubmit,
          child: Text(submitLabel),
        ),
      ],
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(s.xl3, s.xs, s.xl3, s.xl3),
        child: child,
      ),
    );
  }
}

/// A field's label in an action dialog, with the gap above its input.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.sm),
      child: SectionLabel(text),
    );
  }
}

/// The optional free-text note field shared by both dialogs.
class NoteField extends StatelessWidget {
  const NoteField(this.controller, {super.key});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return TextField(
      controller: controller,
      minLines: 3,
      maxLines: 6,
      style: context.typography.body.copyWith(color: c.textPrimary),
      decoration: appInputDecoration(
        context,
        hint: AppL10n.of(context).taskDetailNoteHint,
      ),
    );
  }
}

/// A themed assignee picker fed by [providerUsersProvider].
class AssigneeDropdown extends ConsumerWidget {
  const AssigneeDropdown({
    super.key,
    required this.ticketId,
    required this.value,
    required this.onChanged,
  });
  final String ticketId;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final users = ref.watch(providerUsersProvider(ticketId));
    return users.when(
      loading: () => const AppInlineSpinner(),
      error: (_, _) =>
          AppInlineNote(text: l.taskDetailUsersLoadFailed, isError: true),
      data: (list) => SearchableDropdownField<ProviderUser>(
        items: list,
        value: _selected(list),
        hintText: l.taskDetailSelectUser,
        searchHint: l.searchUsers,
        emptyLabel: l.noMatchingUsers,
        labelOf: (u) => u.displayName,
        searchTextOf: (u) => '${u.displayName} ${u.account}',
        onChanged: (u) => onChanged(u.account),
      ),
    );
  }

  /// Resolves the currently-selected [ProviderUser] from the stored [value]
  /// (a provider account), if any.
  ProviderUser? _selected(List<ProviderUser> list) {
    if (value == null) return null;
    for (final u in list) {
      if (u.account == value) return u;
    }
    return null;
  }
}
