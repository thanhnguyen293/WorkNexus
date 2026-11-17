import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/settings/app_settings.dart';
import '../../../../core/widgets/quick_settings_parts.dart';
import '../../../../l10n/app_localizations.dart';
import 'mcp_setup_dialog.dart';

/// A Quick Settings section: connecting AI tools through the bundled MCP
/// server, and whether they may send chat messages through this app.
class ChatLocalApiSettings extends ConsumerWidget {
  const ChatLocalApiSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final on = ref.watch(appSettingsProvider.select((s) => s.chatLocalApi));
    return QuickSettingsSection(
      title: l.chatLocalApiSection,
      children: [
        QuickSettingsLinkField(
          icon: LucideIcons.plug300,
          label: l.mcpSetupOpen,
          onTap: () => showMcpSetupDialog(context),
        ),
        QuickSettingsSwitchField(
          label: l.chatLocalApi,
          hint: l.chatLocalApiHint,
          value: on,
          onChanged: ref.read(appSettingsProvider.notifier).setChatLocalApi,
        ),
      ],
    );
  }
}
