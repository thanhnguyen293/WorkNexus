import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/code_block.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/mcp_client_config.dart';

/// How to register the MCP server with one AI tool: a heading, where it goes,
/// and the command or config entry to copy.
class McpSetupClientSection extends StatelessWidget {
  const McpSetupClientSection({super.key, required this.config});

  final McpClientConfig config;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final s = context.spacing;
    final t = context.typography;
    final (title, hint) = switch (config.client) {
      McpClient.claudeCode => (l.mcpSetupClaudeCode, l.mcpSetupClaudeCodeHint),
      McpClient.claudeDesktop => (
        l.mcpSetupClaudeDesktop,
        l.mcpSetupClaudeDesktopHint(config.configFile ?? ''),
      ),
      McpClient.other => (l.mcpSetupOtherClient, l.mcpSetupOtherClientHint),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: t.bodyStrong.copyWith(color: c.textPrimary)),
        SizedBox(height: s.xs),
        SelectableText(
          hint,
          style: t.secondary.copyWith(color: c.textSecondary),
        ),
        SizedBox(height: s.md),
        CodeBlock(
          config.snippet,
          fontSize: t.mono.fontSize ?? t.body.fontSize ?? 12,
        ),
      ],
    );
  }
}
