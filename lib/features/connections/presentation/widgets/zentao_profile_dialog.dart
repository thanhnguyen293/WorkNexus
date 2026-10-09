import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/zentao_profile.dart';
import '../providers/zentao_profile_providers.dart';
import 'zentao_profile_edit_dialog.dart';

typedef _Info = ({String label, String? value});

class ZenTaoProfileDialog extends ConsumerWidget {
  const ZenTaoProfileDialog({super.key, required this.account});

  final Account account;

  static Future<void> show(BuildContext context, Account account) =>
      showDialog<void>(
        context: context,
        builder: (_) => ZenTaoProfileDialog(account: account),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final profile = ref.watch(zenTaoProfileProvider(account.id)).asData?.value;
    final refreshing = ref.watch(refreshZenTaoProfileProvider(account));
    final failed = refreshing.hasError || refreshing.asData?.value is Err;
    final name = profile?.realname.isNotEmpty == true
        ? profile!.realname
        : account.handle;

    return Dialog(
      backgroundColor: c.surface,
      insetPadding: EdgeInsets.all(s.xl3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.radii.lg),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 740,
          maxHeight: MediaQuery.sizeOf(context).height - s.xl5 * 2,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(s.xl5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (profile != null)
                    IconButton(
                      tooltip: l.profileEditTitle,
                      onPressed: () => ZenTaoProfileEditDialog.show(
                        context,
                        account: account,
                        profile: profile,
                      ),
                      icon: Icon(Icons.edit_outlined, color: c.textSecondary),
                    ),
                  IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: c.textSecondary),
                  ),
                ],
              ),
              Center(
                child: UserAvatar(
                  name: name,
                  imageUrl: profile?.avatarUrl,
                  diameter: s.xl6 * 1.3,
                ),
              ),
              SizedBox(height: s.sm),
              Text(
                name,
                textAlign: TextAlign.center,
                style: context.typography.title.copyWith(color: c.textPrimary),
              ),
              if (profile?.role case final role?)
                Text(
                  role,
                  textAlign: TextAlign.center,
                  style: context.typography.secondary.copyWith(
                    color: c.textSecondary,
                  ),
                ),
              SizedBox(height: s.xl3),
              if (failed)
                Padding(
                  padding: EdgeInsets.only(bottom: s.xl3),
                  child: Text(
                    l.profileRefreshFailed,
                    style: context.typography.secondary.copyWith(
                      color: c.error,
                    ),
                  ),
                ),
              if (profile == null)
                Padding(
                  padding: EdgeInsets.all(s.xl5),
                  child: Center(
                    child: refreshing.isLoading
                        ? const CircularProgressIndicator()
                        : Text(l.profileUnavailable),
                  ),
                )
              else ...[
                _ProfileSection(
                  title: l.profileBasicInfo,
                  left: [
                    (label: l.profileName, value: profile.realname),
                    (label: l.profileAccount, value: profile.account),
                    (label: l.profileDepartment, value: profile.department),
                    (
                      label: l.profileJoined,
                      value: _date(profile.joined, false),
                    ),
                  ],
                  right: [
                    (label: l.profileGender, value: _gender(l, profile)),
                    (label: l.profileEmail, value: profile.email),
                    (label: l.profileRole, value: profile.role),
                    (label: l.profilePrivilege, value: profile.privilege),
                  ],
                ),
                SizedBox(height: s.xl3),
                _ProfileSection(
                  title: l.profileContactInfo,
                  left: [
                    (label: l.profileMobile, value: profile.mobile),
                    (label: l.profilePhone, value: profile.phone),
                    (label: l.profileZipcode, value: profile.zipcode),
                  ],
                  right: [
                    (label: l.profileWechat, value: profile.wechat),
                    (label: l.profileQq, value: profile.qq),
                    (label: l.profileAddress, value: profile.address),
                  ],
                ),
                SizedBox(height: s.xl3),
                _ProfileSection(
                  title: l.profileAccountInfo,
                  left: [
                    (
                      label: l.profileSvnGitAccount,
                      value: profile.svnGitAccount,
                    ),
                    (label: l.profileVisits, value: profile.visits?.toString()),
                    (
                      label: l.profileLastLogin,
                      value: _date(profile.lastLogin, true),
                    ),
                    (label: l.profileLastIp, value: profile.lastIp),
                  ],
                  right: [
                    (label: l.profileSkype, value: profile.skype),
                    (label: l.profileWhatsapp, value: profile.whatsapp),
                    (label: l.profileSlack, value: profile.slack),
                    (label: l.profileDingding, value: profile.dingding),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String? _gender(AppL10n l, ZenTaoProfile profile) => switch (profile.gender) {
  'm' => l.profileMale,
  'f' => l.profileFemale,
  final value => value,
};

String? _date(String? raw, bool includeTime) {
  if (raw == null) return null;
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  return DateFormat(
    includeTime ? 'yyyy-MM-dd HH:mm:ss' : 'yyyy-MM-dd',
  ).format(parsed.isUtc ? parsed.toLocal() : parsed);
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.title,
    required this.left,
    required this.right,
  });

  final String title;
  final List<_Info> left;
  final List<_Info> right;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final c = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 580;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ColoredBox(
              color: c.surfaceSubtle,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: s.xl, vertical: s.md),
                child: Text(
                  title,
                  style: context.typography.bodyStrong.copyWith(
                    color: c.textPrimary,
                  ),
                ),
              ),
            ),
            SizedBox(height: s.md),
            if (twoColumns)
              for (var i = 0; i < left.length; i++)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: s.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _ProfileField(info: left[i])),
                      SizedBox(width: s.xl3),
                      Expanded(child: _ProfileField(info: right[i])),
                    ],
                  ),
                )
            else
              for (final info in [...left, ...right])
                Padding(
                  padding: EdgeInsets.symmetric(vertical: s.md),
                  child: _ProfileField(info: info),
                ),
          ],
        );
      },
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({required this.info});

  final _Info info;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            info.label,
            textAlign: TextAlign.right,
            style: context.typography.secondary.copyWith(
              color: c.textSecondary,
            ),
          ),
        ),
        SizedBox(width: context.spacing.md),
        Expanded(
          flex: 3,
          child: SelectableText(
            info.value?.isNotEmpty == true
                ? info.value!
                : AppL10n.of(context).profileEmptyValue,
            style: context.typography.secondary.copyWith(color: c.textPrimary),
          ),
        ),
      ],
    );
  }
}
