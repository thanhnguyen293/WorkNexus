import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/mcp_setup.dart';

/// One line on the Node.js the MCP server needs: found and recent enough,
/// too old, or missing.
class McpSetupNodeStatus extends StatelessWidget {
  const McpSetupNodeStatus({super.key, required this.setup});

  final McpSetup setup;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final s = context.spacing;
    const min = McpSetup.minNode;
    final minVersion = '${min.major}.${min.minor}';
    final version = setup.nodeVersion;
    final path = setup.nodePath;
    final (icon, color, text) = switch ((version, path)) {
      (final v?, final p?) when setup.nodeSupported => (
        LucideIcons.circleCheck300,
        c.success,
        l.mcpSetupNodeFound(v, p),
      ),
      (final v?, _) => (
        LucideIcons.triangleAlert300,
        c.warning,
        l.mcpSetupNodeOld(v, minVersion),
      ),
      _ => (LucideIcons.circleX300, c.error, l.mcpSetupNodeMissing(minVersion)),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: s.xl3, color: color),
        SizedBox(width: s.md),
        Expanded(
          child: SelectableText(
            text,
            style: context.typography.body.copyWith(color: c.textPrimary),
          ),
        ),
      ],
    );
  }
}
