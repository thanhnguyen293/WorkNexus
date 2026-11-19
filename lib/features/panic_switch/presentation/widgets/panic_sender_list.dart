import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/panic_switch_config.dart';
import '../providers/panic_switch_providers.dart';
import 'panic_check_row.dart';
import 'panic_switch_save.dart';

/// The team group's members, each ticked when their sticker may set the
/// switch off on this computer. (The demo chat accepts anyone.)
class PanicSenderList extends ConsumerWidget {
  const PanicSenderList({
    super.key,
    required this.accountId,
    required this.config,
  });

  /// Room for about eight people before the list scrolls.
  static const _maxHeight = 280.0;

  final String accountId;
  final PanicSwitchConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final chatGid = config.chatGid;
    if (chatGid == null) return _Note(l.panicSwitchSendersNeedGroup);
    final members = ref.watch(
      panicGroupMembersProvider((accountId: accountId, chatGid: chatGid)),
    );
    return members.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => _Note(l.panicSwitchSendersFailed),
      data: (result) => result.fold(
        (users) => ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: _maxHeight),
          child: ListView(
            shrinkWrap: true,
            children: [
              PanicCheckRow(
                label: l.panicSwitchAnySender,
                picked: config.anySender,
                onToggle: () => savePanicSwitch(
                  context,
                  ref,
                  (c) => c.copyWith(anySender: !c.anySender),
                ),
              ),
              if (!config.anySender)
                for (final user in users)
                  PanicCheckRow(
                    label: user.realname.isEmpty ? user.account : user.realname,
                    detail: user.account,
                    picked: config.allowedSenderIds.contains(user.userId),
                    onToggle: () => savePanicSwitch(
                      context,
                      ref,
                      (c) => c.copyWith(
                        allowedSenderIds:
                            c.allowedSenderIds.contains(user.userId)
                            ? [
                                for (final id in c.allowedSenderIds)
                                  if (id != user.userId) id,
                              ]
                            : [...c.allowedSenderIds, user.userId],
                      ),
                    ),
                  ),
            ],
          ),
        ),
        (_) => _Note(l.panicSwitchSendersFailed),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: context.typography.paragraph.copyWith(
      color: context.colors.textSecondary,
    ),
  );
}
