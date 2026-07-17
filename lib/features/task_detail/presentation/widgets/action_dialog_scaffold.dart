import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// Users the ticket can be (re)assigned to, fetched from its provider.
final providerUsersProvider = FutureProvider.family<List<ProviderUser>, String>(
  (ref, ticketId) async {
    final ticket = ref.read(ticketByIdProvider(ticketId));
    if (ticket == null) return const [];
    final res = await ref.read(syncServiceProvider).listUsers(ticket);
    return res.fold((v) => v, (_) => const <ProviderUser>[]);
  },
);

/// Shared chrome for the ticket action dialogs (Assign / Resolve).
class ActionScaffold extends StatelessWidget {
  const ActionScaffold({
    super.key,
    required this.title,
    required this.emoji,
    required this.child,
    required this.submitLabel,
    required this.onSubmit,
    required this.busy,
    this.canSubmit = true,
  });

  final String title;
  final String emoji;
  final Widget child;
  final String submitLabel;
  final VoidCallback onSubmit;
  final bool busy;
  final bool canSubmit;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AlertDialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.radii.lg),
      ),
      title: Row(
        children: [
          Text(emoji, style: context.typography.title),
          SizedBox(width: context.spacing.md),
          Text(
            title,
            style: context.typography.title.copyWith(color: c.textPrimary),
          ),
        ],
      ),
      content: SizedBox(width: 420, child: child),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: c.textSecondary),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: (busy || !canSubmit) ? null : onSubmit,
          style: FilledButton.styleFrom(
            backgroundColor: c.accent,
            foregroundColor: c.onAccent,
          ),
          child: busy
              ? SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: c.onAccent,
                  ),
                )
              : Text(submitLabel),
        ),
      ],
    );
  }
}

/// Small uppercase label above a dialog field.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.sm),
      child: Text(
        text.toUpperCase(),
        style: context.typography.label.copyWith(
          color: context.colors.textTertiary,
        ),
      ),
    );
  }
}

/// Shared input decoration for the dialog dropdowns / fields.
InputDecoration dropDecoration(BuildContext context) {
  final c = context.colors;
  return InputDecoration(
    isDense: true,
    filled: true,
    fillColor: c.surfaceSubtle,
    contentPadding: EdgeInsets.symmetric(
      horizontal: context.spacing.lg,
      vertical: context.spacing.lg,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(context.radii.md),
      borderSide: BorderSide(color: c.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(context.radii.md),
      borderSide: BorderSide(color: c.border),
    ),
  );
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
      decoration: dropDecoration(context).copyWith(
        hintText: 'Optional note…',
        hintStyle: context.typography.body.copyWith(color: c.textTertiary),
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
    final c = context.colors;
    final users = ref.watch(providerUsersProvider(ticketId));
    return users.when(
      loading: () => const SizedBox(
        height: 20,
        width: 20,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, _) => Text(
        'Could not load users',
        style: context.typography.bodySm.copyWith(color: c.error),
      ),
      data: (list) => DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        dropdownColor: c.surface,
        decoration: dropDecoration(context),
        hint: Text(
          'Select a user',
          style: context.typography.body.copyWith(color: c.textTertiary),
        ),
        style: context.typography.body.copyWith(color: c.textPrimary),
        items: [
          for (final u in list)
            DropdownMenuItem(value: u.account, child: Text(u.displayName)),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
