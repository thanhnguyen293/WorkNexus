import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dialog_frame.dart';
import '../../../../core/widgets/app_dropdown.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../core/widgets/connection_text_field.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/zentao_profile.dart';
import '../../domain/entities/zentao_profile_update.dart';
import '../providers/zentao_profile_edit_controller.dart';
import '../providers/zentao_profile_providers.dart';

class ZenTaoProfileEditDialog extends ConsumerStatefulWidget {
  const ZenTaoProfileEditDialog({
    super.key,
    required this.account,
    required this.profile,
  });

  final Account account;
  final ZenTaoProfile profile;

  static Future<void> show(
    BuildContext context, {
    required Account account,
    required ZenTaoProfile profile,
  }) => showDialog<void>(
    context: context,
    builder: (_) => ZenTaoProfileEditDialog(account: account, profile: profile),
  );

  @override
  ConsumerState<ZenTaoProfileEditDialog> createState() =>
      _ZenTaoProfileEditDialogState();
}

class _ZenTaoProfileEditDialogState
    extends ConsumerState<ZenTaoProfileEditDialog> {
  late final _name = TextEditingController(text: widget.profile.realname);
  late final _email = TextEditingController(text: widget.profile.email ?? '');
  late final _mobile = TextEditingController(text: widget.profile.mobile ?? '');
  late final _phone = TextEditingController(text: widget.profile.phone ?? '');
  late int? _departmentId = widget.profile.departmentId;
  late String? _roleCode = widget.profile.roleCode;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _mobile.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final result = await ref
        .read(zenTaoProfileEditControllerProvider.notifier)
        .update(
          widget.account,
          ZenTaoProfileUpdate(
            realname: _name.text,
            email: _email.text,
            mobile: _mobile.text,
            phone: _phone.text,
            departmentId: _departmentId,
            roleCode: _roleCode,
          ),
        );
    if (!mounted) return;
    switch (result) {
      case Ok():
        Navigator.of(context).pop();
      case Err(:final failure):
        _showMessage(AppL10n.of(context).actionFailed(failure.message));
    }
  }

  void _showMessage(String message) =>
      showAppSnack(context, message, isError: true);

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final s = context.spacing;
    final busy = ref.watch(zenTaoProfileEditControllerProvider).isLoading;
    final departments =
        ref.watch(zenTaoDepartmentsProvider(widget.account.id)).asData?.value ??
        const [];
    final current = ref
        .watch(zenTaoProfileProvider(widget.account.id))
        .asData
        ?.value;
    final departmentLabels = <int?, String>{
      for (final department in departments) department.id: department.path,
      if (_departmentId case final id?
          when !departments.any((item) => item.id == id))
        id: widget.profile.department ?? '$id',
    };
    final roles = <String?, String>{
      'dev': l.chatRoleDev,
      'qa': l.chatRoleQa,
      'pm': l.chatRolePm,
      'po': l.chatRolePo,
      'td': l.chatRoleTd,
      'pd': l.chatRolePd,
      'qd': l.chatRoleQd,
      'top': l.chatRoleTop,
      'others': l.chatRoleOthers,
    };
    if (_roleCode case final code? when !roles.containsKey(code)) {
      roles[code] = widget.profile.role ?? code;
    }
    void submit(String _) {
      if (!busy) _save();
    }

    return AppDialogFrame(
      title: l.profileEditTitle,
      maxWidth: context.sizes.dialogMd,
      maxHeight: MediaQuery.sizeOf(context).height - s.xl5 * 2,
      actions: [
        const Spacer(),
        AppButton.textNeutral(
          onPressed: busy ? null : () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        AppButton.filled(
          isLoading: busy,
          onPressed: busy ? null : _save,
          child: Text(l.save),
        ),
      ],
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(s.xl3, 0, s.xl3, s.xl3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: UserAvatar(
                name: current?.realname ?? widget.profile.realname,
                imageUrl: current?.avatarUrl ?? widget.profile.avatarUrl,
                diameter: s.xl6 * 1.5,
              ),
            ),
            SizedBox(height: s.xl3),
            ConnectionTextField(
              label: l.profileName,
              controller: _name,
              onSubmitted: submit,
            ),
            SizedBox(height: s.lg),
            ConnectionTextField(
              label: l.profileEmail,
              controller: _email,
              onSubmitted: submit,
            ),
            SizedBox(height: s.lg),
            ConnectionTextField(
              label: l.profileMobile,
              controller: _mobile,
              onSubmitted: submit,
            ),
            SizedBox(height: s.lg),
            ConnectionTextField(
              label: l.profilePhone,
              controller: _phone,
              onSubmitted: submit,
            ),
            SizedBox(height: s.lg),
            _DropdownField<int?>(
              label: l.profileDepartment,
              value: _departmentId,
              labels: departmentLabels,
              enabled: !busy,
              onChanged: (value) => setState(() => _departmentId = value),
            ),
            SizedBox(height: s.lg),
            _DropdownField<String?>(
              label: l.profileRole,
              value: _roleCode,
              labels: roles,
              enabled: !busy,
              onChanged: (value) => setState(() => _roleCode = value),
            ),
          ],
        ),
      ),
    );
  }
}

/// A labelled [AppDropdown] laid out like [ConnectionTextField]. [labels]
/// maps each choice to its text; an unset [value] reads as "—".
class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.labels,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final T value;
  final Map<T, String> labels;
  final bool enabled;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: context.typography.captionStrong.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
        SizedBox(height: context.spacing.xs),
        IgnorePointer(
          ignoring: !enabled,
          child: AppDropdown<T>(
            value: value,
            values: labels.keys.toList(),
            labelOf: (v) => labels[v] ?? l.profileEmptyValue,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
