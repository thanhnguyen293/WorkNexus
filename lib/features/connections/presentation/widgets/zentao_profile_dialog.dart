import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_dialog_frame.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/app_state_view.dart';
import '../../../../core/widgets/inline_status.dart';
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
    final realname = profile?.realname ?? '';
    final name = realname.isNotEmpty ? realname : account.handle;

    return AppDialogFrame(
      title: name,
      maxWidth: context.sizes.dialogLg,
      maxHeight: MediaQuery.sizeOf(context).height - s.xl5 * 2,
      headerTrailing: profile == null
          ? null
          : AppIconButton(
              icon: LucideIcons.pencil300,
              tooltip: l.profileEditTitle,
              onPressed: () => ZenTaoProfileEditDialog.show(
                context,
                account: account,
                profile: profile,
              ),
            ),
      actions: const [],
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(s.xl3, 0, s.xl3, s.xl3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: UserAvatar(
                name: name,
                imageUrl: profile?.avatarUrl,
                diameter: s.xl6 * 1.3,
              ),
            ),
            if (profile?.role case final role?) ...[
              SizedBox(height: s.sm),
              Text(
                role,
                textAlign: TextAlign.center,
                style: context.typography.secondary.copyWith(
                  color: c.textSecondary,
                ),
              ),
            ],
            SizedBox(height: s.xl3),
            if (profile == null)
              if (refreshing.isLoading)
                const AppStateView.loading(compact: true)
              else if (failed)
                AppStateView.error(
                  compact: true,
                  title: l.profileUnavailable,
                  onRetry: () =>
                      ref.invalidate(refreshZenTaoProfileProvider(account)),
                )
              else
                AppStateView.empty(
                  compact: true,
                  icon: LucideIcons.userX300,
                  title: l.profileUnavailable,
                )
            else ...[
              if (failed) ...[
                AppInlineNote(text: l.profileRefreshFailed, isError: true),
                SizedBox(height: s.xl3),
              ],
              _ProfileSections(profile: profile),
            ],
          ],
        ),
      ),
    );
  }
}

/// The profile's three groups of fields.
class _ProfileSections extends StatelessWidget {
  const _ProfileSections({required this.profile});

  final ZenTaoProfile profile;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final l = AppL10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProfileSection(
          title: l.profileBasicInfo,
          left: [
            (label: l.profileName, value: profile.realname),
            (label: l.profileAccount, value: profile.account),
            (label: l.profileDepartment, value: profile.department),
            (label: l.profileJoined, value: _date(profile.joined, false)),
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
            (label: l.profileSvnGitAccount, value: profile.svnGitAccount),
            (label: l.profileVisits, value: profile.visits?.toString()),
            (label: l.profileLastLogin, value: _date(profile.lastLogin, true)),
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
            switch (info.value) {
              final value? when value.isNotEmpty => value,
              _ => AppL10n.of(context).profileEmptyValue,
            },
            style: context.typography.secondary.copyWith(color: c.textPrimary),
          ),
        ),
      ],
    );
  }
}
