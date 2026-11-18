import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/mcp_setup.dart';

/// One line on the Node.js the MCP server needs: found and recent enough,
/// too old, or missing — plus a warning when it comes from a version manager,
/// whose path breaks once that version is switched away from or removed.
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
    final status = _StatusLine(icon: icon, color: color, text: text);
    if (!setup.nodeFromVersionManager) return status;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        status,
        SizedBox(height: s.sm),
        _StatusLine(
          icon: LucideIcons.info300,
          color: c.warning,
          text: l.mcpSetupNodeVersionManager,
        ),
      ],
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: s.xl3, color: color),
        SizedBox(width: s.md),
        Expanded(
          child: SelectableText(
            text,
            style: context.typography.body.copyWith(
              color: context.colors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
