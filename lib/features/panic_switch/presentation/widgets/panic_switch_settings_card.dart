import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/widgets/app_expandable_card.dart';
import '../../../../core/widgets/app_segmented_tabs.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/panic_switch_config.dart';
import '../providers/panic_switch_config_controller.dart';
import '../providers/panic_switch_providers.dart';
import 'panic_app_pickers.dart';
import 'panic_chat_picker.dart';
import 'panic_sender_list.dart';
import 'panic_switch_save.dart';
import 'panic_try_button.dart';

/// The debounce choices offered, in seconds.
const _debounceChoices = [15, 30, 60, 120, 300];

/// Settings' "Thầy vô" card: the floating button that sends the sticker, and
/// what this computer does when the sticker arrives. Shown only to users of
/// the ZenTao the feature is offered for.
class PanicSwitchSettingsCard extends ConsumerWidget {
  const PanicSwitchSettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(panicSwitchAccountProvider);
    if (account == null) return const SizedBox.shrink();
    final l = AppL10n.of(context);
    final loaded = ref.watch(panicSwitchConfigProvider);
    if (loaded.hasError) {
      return AppExpandableCard(
        icon: LucideIcons.siren300,
        title: l.panicSwitchTitle,
        summary: l.panicSwitchLoadFailed,
        sections: const [],
      );
    }
    final config = loaded.asData?.value;
    if (config == null) return const SizedBox.shrink();
    final canRaise = ref.watch(appSwitcherProvider).canRaiseApps;
    final chats =
        ref.watch(
          panicChatsProvider((
            accountId: account.id,
            selfTitle: l.panicSwitchSelfChat,
          )),
        ) ??
        const [];
    String? titleOf(String? gid) =>
        chats.where((c) => c.chat.gid == gid).firstOrNull?.title;
    final team = titleOf(config.chatGid);
    final listening = titleOf(config.receiveChatGid);
    void save(PanicSwitchConfig Function(PanicSwitchConfig) change) =>
        savePanicSwitch(context, ref, change);

    return AppExpandableCard(
      icon: LucideIcons.siren300,
      title: l.panicSwitchTitle,
      summary: config.testMode
          ? l.panicSwitchSummaryTestMode
          : listening == null
          ? l.panicSwitchNoGroup
          : config.anySender
          ? l.panicSwitchSummaryAnyone(listening)
          : l.panicSwitchSummary(listening, config.allowedSenderIds.length),
      sections: [
        AppExpandableCardSection(
          title: l.panicSwitchOverlayLabel,
          hint: l.panicSwitchOverlayHint,
          trailing: Switch(
            value: config.overlayVisible,
            onChanged: (v) => save((c) => c.copyWith(overlayVisible: v)),
          ),
        ),
        AppExpandableCardSection(
          title: l.panicSwitchGroupLabel,
          hint: l.panicSwitchTeamGroupHint,
          trailing: Text(team ?? l.panicSwitchNoGroup),
        ),
        AppExpandableCardSection(
          title: l.panicSwitchTestModeLabel,
          hint: l.panicSwitchTestModeHint,
          trailing: Switch(
            value: config.testMode,
            onChanged: (v) => save((c) => c.copyWith(testMode: v)),
          ),
        ),
        if (config.testMode) ...[
          AppExpandableCardSection(
            title: l.panicSwitchTestSendLabel,
            hint: l.panicSwitchTestSendHint,
            child: PanicChatPicker(
              chats: chats,
              value: config.testSendChatGid,
              onChanged: (p) => save(
                (c) => c.copyWith(
                  testSendChatGid: p.chat.gid,
                  testSendToSelf: p.chat.isMyCloud,
                ),
              ),
            ),
          ),
          AppExpandableCardSection(
            title: l.panicSwitchTestReceiveLabel,
            hint: l.panicSwitchTestReceiveHint,
            child: PanicChatPicker(
              // Your own messages never arrive as incoming: My Cloud would
              // never set it off.
              chats: [
                for (final c in chats)
                  if (!c.chat.isMyCloud) c,
              ],
              value: config.testReceiveChatGid,
              // Senders allowed in one chat mean nothing in another.
              onChanged: (p) => save(
                (c) => c.testReceiveChatGid == p.chat.gid
                    ? c
                    : c.copyWith(
                        testReceiveChatGid: p.chat.gid,
                        allowedSenderIds: const [],
                      ),
              ),
            ),
          ),
        ],
        AppExpandableCardSection(
          title: l.panicSwitchReceiveLabel,
          hint: l.panicSwitchReceiveHint,
          trailing: Switch(
            value: config.enabled,
            onChanged: (v) => save((c) => c.copyWith(enabled: v)),
          ),
        ),
        AppExpandableCardSection(
          title: l.panicSwitchSendersLabel,
          hint: l.panicSwitchSendersHint,
          child: PanicSenderList(accountId: account.id, config: config),
        ),
        AppExpandableCardSection(
          title: l.panicSwitchTargetLabel,
          hint: !canRaise
              ? '${l.panicSwitchTargetHint} ${l.panicSwitchWaylandNote}'
              : l.panicSwitchTargetHint,
          child: PanicTargetAppPicker(config: config),
        ),
        AppExpandableCardSection(
          title: l.panicSwitchHideLabel,
          hint: l.panicSwitchHideHint,
          child: PanicHiddenAppsPicker(config: config),
        ),
        AppExpandableCardSection(
          title: l.panicSwitchTryLabel,
          hint: l.panicSwitchTryHint,
          trailing: const PanicTryButton(),
        ),
        AppExpandableCardSection(
          title: l.panicSwitchHideSelfLabel,
          hint: l.panicSwitchHideSelfHint,
          trailing: Switch(
            value: config.hideSelf,
            onChanged: (v) => save((c) => c.copyWith(hideSelf: v)),
          ),
        ),
        AppExpandableCardSection(
          title: l.panicSwitchDebounceLabel,
          hint: l.panicSwitchDebounceHint,
          trailing: AppSegmentedTabs(
            tabs: [
              for (final s in _debounceChoices)
                AppSegmentedTab(
                  label: l.panicSwitchSeconds(s),
                  active: config.debounceSeconds == s,
                  onTap: () => save((c) => c.copyWith(debounceSeconds: s)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
