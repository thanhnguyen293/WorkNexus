import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_input_decoration.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../core/widgets/celebration_overlay.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../sync/data/sync_service.dart';
import 'action_dialog_scaffold.dart';

/// ZenTao's own bug resolution codes, in the order the picker lists them.
const _resolutionCodes = [
  'fixed',
  'bydesign',
  'duplicate',
  'external',
  'notrepro',
  'willnotfix',
  'postponed',
  'tostory',
];

String _resolutionLabel(AppL10n l, String code) => switch (code) {
  'fixed' => l.taskDetailResolutionFixed,
  'bydesign' => l.taskDetailResolutionByDesign,
  'duplicate' => l.taskDetailResolutionDuplicate,
  'external' => l.taskDetailResolutionExternal,
  'notrepro' => l.taskDetailResolutionNotRepro,
  'willnotfix' => l.taskDetailResolutionWontFix,
  'postponed' => l.taskDetailResolutionPostponed,
  'tostory' => l.taskDetailResolutionToStory,
  _ => code,
};

/// Resolves a ZenTao bug: resolution code, build, optional assignee + note.
class ResolveDialog extends ConsumerStatefulWidget {
  const ResolveDialog({super.key, required this.ticket});
  final Ticket ticket;

  @override
  ConsumerState<ResolveDialog> createState() => _ResolveDialogState();
}

class _ResolveDialogState extends ConsumerState<ResolveDialog> {
  final _note = TextEditingController();
  final _build = TextEditingController(text: 'trunk');
  String? _resolution;
  String? _assignee;
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    _build.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final resolution = _resolution;
    if (resolution == null || _busy) return;
    final l = AppL10n.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    final res = await getIt<SyncService>().resolveBug(
      widget.ticket,
      resolution: resolution,
      build: _build.text,
      assignee: _assignee,
      comment: _note.text,
    );
    if (!mounted) return;
    // Fireworks for a fix only, not for duplicate / by design / won't fix.
    if (res.isOk && resolution == 'fixed') {
      ref.read(celebrationProvider.notifier).celebrate();
    }
    showAppSnack(
      context,
      res.isOk
          ? l.taskDetailResolvedAs(_resolutionLabel(l, resolution))
          : l.actionFailed(
              res.failureOrNull?.message ?? l.providerActionFailed,
            ),
      isError: !res.isOk,
    );
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    return ActionScaffold(
      title: l.zentaoActionTitle(l.resolve, widget.ticket.externalKey),
      submitLabel: l.resolve,
      icon: LucideIcons.checkCircle300,
      busy: _busy,
      canSubmit: _resolution != null,
      onSubmit: _submit,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldLabel(l.taskDetailResolutionRequired),
          SearchableDropdownField<String>(
            items: _resolutionCodes,
            value: _resolution,
            hintText: l.taskDetailSelectResolution,
            searchHint: l.taskDetailSearchResolutions,
            emptyLabel: l.taskDetailNoMatchingResolutions,
            labelOf: (code) => _resolutionLabel(l, code),
            onChanged: (v) => setState(() => _resolution = v),
          ),
          SizedBox(height: context.spacing.xl2),
          FieldLabel(l.zentaoBuild),
          TextField(
            controller: _build,
            onSubmitted: (_) => _submit(),
            style: context.typography.body.copyWith(color: c.textPrimary),
            decoration: appInputDecoration(context),
          ),
          SizedBox(height: context.spacing.xl2),
          FieldLabel(l.zentaoAssignToOptional),
          AssigneeDropdown(
            ticketId: widget.ticket.id,
            value: _assignee,
            onChanged: (v) => setState(() => _assignee = v),
          ),
          SizedBox(height: context.spacing.xl2),
          FieldLabel(l.zentaoNote),
          NoteField(_note),
        ],
      ),
    );
  }
}
