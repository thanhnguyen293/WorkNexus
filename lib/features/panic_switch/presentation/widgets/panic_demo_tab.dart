import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_expandable_card.dart';
import '../../../../core/widgets/inline_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/panic_switch_config.dart';
import '../../domain/usecases/list_panic_chats.dart';
import 'panic_chat_picker.dart';
import 'panic_labels.dart';
import 'panic_steps.dart';
import 'panic_switch_save.dart';

/// The "Demo" tab: a second trigger, with the right mouse button and a chat
/// of your own, to try the switch without bothering the team. It shares the
/// apps and the floating button with the official tab.
class PanicDemoTab extends ConsumerWidget {
  const PanicDemoTab({super.key, required this.config, required this.chats});

  final PanicSwitchConfig config;
  final List<PanicChat> chats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final s = context.spacing;
    final chat = chats
        .where((c) => c.chat.gid == config.demoChatGid)
        .firstOrNull
        ?.title;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(s.xl2, s.none, s.xl2, s.xl2),
          child: PanicSteps(
            title: l.panicSwitchHowTitle,
            steps: [
              (
                LucideIcons.mousePointerClick300,
                l.panicSwitchDemoStep1(gestureLabel(l, config.overlayGesture)),
              ),
              (
                LucideIcons.send300,
                l.panicSwitchDemoStep2(chat ?? l.panicSwitchDemoChatFallback),
              ),
              (LucideIcons.flaskConical300, l.panicSwitchDemoStep3),
            ],
          ),
        ),
        AppExpandableCardSection(
          title: l.panicSwitchDemoModeLabel,
          hint: l.panicSwitchDemoModeHint,
          trailing: Switch(
            value: config.demoMode,
            onChanged: (v) =>
                savePanicSwitch(context, ref, (c) => c.copyWith(demoMode: v)),
          ),
        ),
        if (config.demoMode)
          AppExpandableCardSection(
            title: l.panicSwitchDemoChatLabel,
            hint: l.panicSwitchDemoChatHint,
            child: PanicChatPicker(
              chats: chats,
              value: config.demoChatGid,
              onChanged: (p) => savePanicSwitch(
                context,
                ref,
                (c) => c.copyWith(demoChatGid: p.chat.gid),
              ),
            ),
          ),
        Padding(
          padding: EdgeInsets.all(s.xl2),
          child: AppInlineNote(text: l.panicSwitchDemoShared),
        ),
      ],
    );
  }
}
