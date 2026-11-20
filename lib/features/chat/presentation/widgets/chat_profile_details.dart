import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/person_profile.dart';
import '../../../../core/error/result.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/util/relative_time.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_user.dart';
import '../providers/chat_person_providers.dart';
import 'chat_profile_info_row.dart';
import 'chat_profile_section.dart';

/// The Contact and Work sections of a person's profile: what chat knows of
/// them, completed by the tracker's profile once it answers. Empty fields are
/// left out, and so is a section with nothing to show.
class ChatProfileDetails extends ConsumerWidget {
  const ChatProfileDetails({super.key, required this.person, this.user});

  final ChatPersonKey person;
  final ChatUser? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final fetch = ref.watch(chatPersonProfileProvider(person));
    final profile = switch (fetch.value) {
      Ok(:final value) => value,
      _ => null,
    };
    final failed = fetch.value is Err || fetch.hasError;
    final loading = fetch.isLoading;
    final contacts = _contacts(l, profile);
    final work = _work(context, l, profile);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (contacts.isNotEmpty || loading)
          ChatProfileSection(
            title: l.chatProfileContact,
            children: contacts.isEmpty
                ? const [ChatProfileLoadingRows()]
                : contacts,
          ),
        // The skeleton shows once: under Contact while that is empty too.
        if (work.isNotEmpty ||
            (loading && contacts.isNotEmpty) ||
            (failed && contacts.isEmpty))
          ChatProfileSection(
            title: l.chatProfileOrganisation,
            children: [
              ...work,
              if (work.isEmpty && loading) const ChatProfileLoadingRows(),
              if (work.isEmpty && !loading)
                ChatProfileNote(l.chatProfileLoadFailed, isError: true),
            ],
          ),
      ],
    );
  }

  List<Widget> _contacts(AppL10n l, PersonProfile? p) {
    final u = user;
    Widget? row(IconData icon, String label, String? value) =>
        value == null || value.trim().isEmpty
        ? null
        : ChatProfileInfoRow(
            icon: icon,
            label: label,
            value: value.trim(),
            copyable: true,
          );
    return [
      ?row(LucideIcons.mail300, l.chatEmail, u?.email ?? p?.email),
      ?row(LucideIcons.smartphone300, l.chatMobile, u?.mobile ?? p?.mobile),
      ?row(LucideIcons.phone300, l.chatPhone, u?.phone ?? p?.phone),
      ?row(LucideIcons.messageCircle300, l.profileWechat, p?.wechat),
      ?row(LucideIcons.messagesSquare300, l.profileSlack, p?.slack),
      ?row(LucideIcons.video300, l.profileSkype, p?.skype),
      ?row(LucideIcons.messageCircleMore300, l.profileWhatsapp, p?.whatsapp),
      ?row(LucideIcons.atSign300, l.profileQq, p?.qq),
      ?row(LucideIcons.send300, l.profileDingding, p?.dingding),
    ];
  }

  List<Widget> _work(BuildContext context, AppL10n l, PersonProfile? p) {
    if (p == null) return const [];
    String date(DateTime t) =>
        formatDate(context, t, format: DateDisplayFormat.long);
    return [
      if (p.department case final dept?)
        ChatProfileInfoRow(
          icon: LucideIcons.building2300,
          label: l.profileDepartment,
          value: dept,
        ),
      if (p.joined case final joined?)
        ChatProfileInfoRow(
          icon: LucideIcons.calendarCheck300,
          label: l.profileJoined,
          value: date(joined),
        ),
      if (p.lastLogin case final last?)
        ChatProfileInfoRow(
          icon: LucideIcons.history300,
          label: l.profileLastLogin,
          value: formatDate(
            context,
            last,
            format: DateDisplayFormat.long,
            withTime: true,
          ),
        ),
      if (p.address case final address?)
        ChatProfileInfoRow(
          icon: LucideIcons.mapPin300,
          label: l.profileAddress,
          value: address,
        ),
    ];
  }
}
