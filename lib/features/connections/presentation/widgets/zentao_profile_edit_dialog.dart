import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/zentao_profile.dart';
import '../../domain/entities/zentao_profile_update.dart';
import '../providers/zentao_profile_edit_controller.dart';
import '../providers/zentao_profile_providers.dart';
import 'connection_text_field.dart';

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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final c = context.colors;
    final s = context.spacing;
    final busy = ref.watch(zenTaoProfileEditControllerProvider).isLoading;
    final departments =
        ref.watch(zenTaoDepartmentsProvider(widget.account.id)).asData?.value ??
        const [];
    final current = ref
        .watch(zenTaoProfileProvider(widget.account.id))
        .asData
        ?.value;
    final departmentOptions = [
      for (final department in departments)
        DropdownMenuItem<int>(
          value: department.id,
          child: Text(department.path, overflow: TextOverflow.ellipsis),
        ),
      if (_departmentId != null &&
          !departments.any((item) => item.id == _departmentId))
        DropdownMenuItem<int>(
          value: _departmentId,
          child: Text(widget.profile.department ?? '$_departmentId'),
        ),
    ];
    final roles = <String, String>{
      'dev': l.chatRoleDev,
      'qa': l.chatRoleQa,
      'pm': l.chatRolePm,
      'po': l.chatRolePo,
      'td': l.chatRoleTd,
      'pd': l.chatRolePd,
      'qd': l.chatRoleQd,
      'top': l.chatRoleTop,
      'others': l.chatRoleOthers,
      if (_roleCode != null &&
          !{
            'dev',
            'qa',
            'pm',
            'po',
            'td',
            'pd',
            'qd',
            'top',
            'others',
          }.contains(_roleCode))
        _roleCode!: widget.profile.role ?? _roleCode!,
    };

    return Dialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.radii.lg),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.sizeOf(context).height - s.xl5 * 2,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(s.xl4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.profileEditTitle,
                style: context.typography.title.copyWith(color: c.textPrimary),
              ),
              SizedBox(height: s.xl3),
              Center(
                child: UserAvatar(
                  name: current?.realname ?? widget.profile.realname,
                  imageUrl: current?.avatarUrl ?? widget.profile.avatarUrl,
                  diameter: s.xl6 * 1.5,
                ),
              ),
              SizedBox(height: s.xl3),
              ConnectionTextField(label: l.profileName, controller: _name),
              SizedBox(height: s.lg),
              ConnectionTextField(label: l.profileEmail, controller: _email),
              SizedBox(height: s.lg),
              ConnectionTextField(label: l.profileMobile, controller: _mobile),
              SizedBox(height: s.lg),
              ConnectionTextField(label: l.profilePhone, controller: _phone),
              SizedBox(height: s.lg),
              Text(
                l.profileDepartment,
                style: context.typography.captionStrong,
              ),
              DropdownButtonFormField<int>(
                initialValue: _departmentId,
                items: departmentOptions,
                onChanged: busy
                    ? null
                    : (value) => setState(() => _departmentId = value),
              ),
              SizedBox(height: s.lg),
              Text(l.profileRole, style: context.typography.captionStrong),
              DropdownButtonFormField<String>(
                initialValue: _roleCode,
                items: [
                  for (final entry in roles.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: busy
                    ? null
                    : (value) => setState(() => _roleCode = value),
              ),
              SizedBox(height: s.xl3),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton.textNeutral(
                    onPressed: busy ? null : () => Navigator.of(context).pop(),
                    child: Text(l.cancel),
                  ),
                  SizedBox(width: s.sm),
                  AppButton.filled(
                    isLoading: busy,
                    onPressed: busy ? null : _save,
                    child: Text(l.save),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
