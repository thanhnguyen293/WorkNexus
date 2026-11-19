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
import 'panic_button_group.dart';
import 'panic_chat_picker.dart';
import 'panic_group_label.dart';
import 'panic_how_it_works.dart';
import 'panic_sender_list.dart';
import 'panic_switch_save.dart';
import 'panic_try_button.dart';

/// The debounce choices offered, in seconds.
const _debounceChoices = [15, 30, 60, 120, 300];

/// Settings' "Thầy vô" card. It opens on how the switch works with the
/// user's own settings filled in, then groups the settings in the order they
/// come into play: the floating button, what this computer does, receiving,
/// demo mode, and the rest. Shown only to users of the ZenTao the feature is
/// offered for.
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
    final demoChat = config.demoMode ? titleOf(config.demoChatGid) : null;
    final summary = team == null
        ? l.panicSwitchNoGroup
        : config.anySender
        ? l.panicSwitchSummaryAnyone(team)
        : l.panicSwitchSummary(team, config.allowedSenderIds.length);
    void save(PanicSwitchConfig Function(PanicSwitchConfig) change) =>
        savePanicSwitch(context, ref, change);

    return AppExpandableCard(
      icon: LucideIcons.siren300,
      title: l.panicSwitchTitle,
      summary: config.demoMode
          ? l.panicSwitchSummaryWithDemo(summary)
          : summary,
      sections: [
        PanicHowItWorks(
          gesture: config.overlayGesture,
          team: team ?? l.panicSwitchTeamFallback,
          demoChat: demoChat,
        ),
        PanicButtonGroup(config: config),

        PanicGroupLabel(l.panicSwitchSectionAction),
        AppExpandableCardSection(
          title: l.panicSwitchTargetLabel,
          hint: !canRaise
              ? '${l.panicSwitchTargetHint} ${l.panicSwitchWaylandNote}'
              : l.panicSwitchTargetHint,
          child: PanicOpenAppsPicker(config: config),
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
          title: l.panicSwitchTryLabel,
          hint: l.panicSwitchTryHint,
          trailing: const PanicTryButton(),
        ),

        PanicGroupLabel(l.panicSwitchSectionReceive),
        AppExpandableCardSection(
          title: l.panicSwitchReceiveLabel,
          hint: l.panicSwitchReceiveHint,
          trailing: Switch(
            value: config.enabled,
            onChanged: (v) => save((c) => c.copyWith(enabled: v)),
          ),
        ),
        AppExpandableCardSection(
          title: l.panicSwitchGroupLabel,
          hint: l.panicSwitchTeamGroupHint,
          trailing: Text(team ?? l.panicSwitchNoGroup),
        ),
        if (config.enabled)
          AppExpandableCardSection(
            title: l.panicSwitchSendersLabel,
            hint: l.panicSwitchSendersHint,
            child: PanicSenderList(accountId: account.id, config: config),
          ),

        PanicGroupLabel(l.panicSwitchSectionDemo),
        AppExpandableCardSection(
          title: l.panicSwitchDemoModeLabel,
          hint: l.panicSwitchDemoModeHint,
          trailing: Switch(
            value: config.demoMode,
            onChanged: (v) => save((c) => c.copyWith(demoMode: v)),
          ),
        ),
        if (config.demoMode)
          AppExpandableCardSection(
            title: l.panicSwitchDemoChatLabel,
            hint: l.panicSwitchDemoChatHint,
            child: PanicChatPicker(
              chats: chats,
              value: config.demoChatGid,
              onChanged: (p) =>
                  save((c) => c.copyWith(demoChatGid: p.chat.gid)),
            ),
          ),

        PanicGroupLabel(l.panicSwitchSectionAdvanced),
        AppExpandableCardSection(
          title: l.panicSwitchDebounceLabel,
          hint: l.panicSwitchDebounceHint,
          child: AppSegmentedTabs(
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
