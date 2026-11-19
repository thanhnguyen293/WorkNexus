import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_expandable_card.dart';
import '../../../../core/widgets/app_segmented_tabs.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/panic_switch_config.dart';
import '../../domain/usecases/list_panic_chats.dart';
import '../providers/panic_switch_config_controller.dart';
import '../providers/panic_switch_providers.dart';
import 'panic_demo_tab.dart';
import 'panic_release_tab.dart';

/// Settings' "Thầy vô" card, in two tabs so neither reads as one long list:
/// "Official" (the team group) and "Demo" (a chat of your own). Shown only to
/// users of the ZenTao the feature is offered for.
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
    final chats =
        ref.watch(
          panicChatsProvider((
            accountId: account.id,
            selfTitle: l.panicSwitchSelfChat,
          )),
        ) ??
        const <PanicChat>[];
    final team = chats
        .where((c) => c.chat.gid == config.chatGid)
        .firstOrNull
        ?.title;
    final summary = team == null
        ? l.panicSwitchNoGroup
        : config.anySender
        ? l.panicSwitchSummaryAnyone(team)
        : l.panicSwitchSummary(team, config.allowedSenderIds.length);

    return AppExpandableCard(
      icon: LucideIcons.siren300,
      title: l.panicSwitchTitle,
      summary: config.demoMode
          ? l.panicSwitchSummaryWithDemo(summary)
          : summary,
      sections: [
        _ModeTabs(
          config: config,
          accountId: account.id,
          team: team ?? l.panicSwitchTeamFallback,
          chats: chats,
          canRaise: ref.watch(appSwitcherProvider).canRaiseApps,
        ),
      ],
    );
  }
}

/// The two tabs and the open one's settings.
class _ModeTabs extends StatefulWidget {
  const _ModeTabs({
    required this.config,
    required this.accountId,
    required this.team,
    required this.chats,
    required this.canRaise,
  });

  final PanicSwitchConfig config;
  final String accountId;
  final String team;
  final List<PanicChat> chats;
  final bool canRaise;

  @override
  State<_ModeTabs> createState() => _ModeTabsState();
}

class _ModeTabsState extends State<_ModeTabs> {
  var _demo = false;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final s = context.spacing;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.colors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(s.xl2),
            child: AppSegmentedTabs(
              tabs: [
                AppSegmentedTab(
                  label: l.panicSwitchTabRelease,
                  active: !_demo,
                  onTap: () => setState(() => _demo = false),
                ),
                AppSegmentedTab(
                  label: widget.config.demoMode
                      ? l.panicSwitchTabDemoOn
                      : l.panicSwitchTabDemo,
                  active: _demo,
                  onTap: () => setState(() => _demo = true),
                ),
              ],
            ),
          ),
          if (_demo)
            PanicDemoTab(config: widget.config, chats: widget.chats)
          else
            PanicReleaseTab(
              config: widget.config,
              accountId: widget.accountId,
              team: widget.team,
              canRaise: widget.canRaise,
            ),
        ],
      ),
    );
  }
}
