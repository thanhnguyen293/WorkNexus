import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/platform/open_external.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dialog_frame.dart';
import '../../../../core/widgets/app_state_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/mcp_setup.dart';
import '../providers/mcp_setup_providers.dart';
import 'mcp_setup_client_section.dart';
import 'mcp_setup_node_status.dart';

const _nodeDownloadUrl = 'https://nodejs.org/en/download';

/// Shows how to connect AI tools to WorkNexus through its bundled MCP server.
Future<void> showMcpSetupDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const McpSetupDialog());

/// The MCP setup guide: whether Node.js is ready, then the command / config
/// entry for each AI tool, with absolute paths filled in.
class McpSetupDialog extends ConsumerWidget {
  const McpSetupDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final setup = ref.watch(mcpSetupProvider);
    final nodeMissing = !(setup.value?.nodeSupported ?? true);
    return AppDialogFrame(
      title: l.mcpSetupTitle,
      leadingIcon: LucideIcons.plug300,
      maxWidth: context.sizes.dialogLg,
      actions: [
        const Spacer(),
        if (nodeMissing)
          AppButton.textNeutral(
            size: AppButtonSize.small,
            icon: LucideIcons.download300,
            onPressed: () => openExternally(_nodeDownloadUrl),
            child: Text(l.mcpSetupGetNode),
          ),
        AppButton.filled(
          size: AppButtonSize.small,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.gotIt),
        ),
      ],
      child: switch (setup) {
        AsyncData(:final value) => _Guide(setup: value),
        AsyncError(:final error) => AppStateView.error(
          title: l.mcpSetupFailed,
          message: error is Failure ? error.message : '$error',
          compact: true,
        ),
        _ => const AppStateView.loading(compact: true),
      },
    );
  }
}

class _Guide extends StatelessWidget {
  const _Guide({required this.setup});

  final McpSetup setup;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final s = context.spacing;
    final note = context.typography.paragraph.copyWith(color: c.textSecondary);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(s.xl3, 0, s.xl3, s.xl3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.mcpSetupIntro, style: note),
          SizedBox(height: s.xl),
          McpSetupNodeStatus(setup: setup),
          for (final config in mcpClientConfigs(setup)) ...[
            SizedBox(height: s.xl2),
            McpSetupClientSection(config: config),
          ],
          SizedBox(height: s.xl2),
          Text(l.mcpSetupSendNote, style: note),
        ],
      ),
    );
  }
}
