import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/agent_kind.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../agents/presentation/agent_providers.dart';
import '../detail_providers.dart';
import 'agent_sessions.dart';
import 'detail_scroll_body.dart';
import 'section_label.dart';

/// The "Development" tab — linked code, and coding-agent dispatch.
class DevelopmentTab extends ConsumerWidget {
  const DevelopmentTab({super.key, required this.ticket, required this.layout});
  final Ticket ticket;
  final DetailLayout layout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final links = ref.watch(devLinksProvider(ticket.id));
    return DetailScrollBody(
      layout: layout,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Linked code'),
          SizedBox(height: context.spacing.lg),
          links.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (list) => list.isEmpty
                ? Text(
                    'No linked branches or PRs yet.',
                    style: context.typography.secondary.copyWith(
                      color: c.textTertiary,
                    ),
                  )
                : Column(
                    children: [
                      for (final link in list)
                        Container(
                          margin: EdgeInsets.only(bottom: context.spacing.md),
                          padding: EdgeInsets.symmetric(
                            horizontal: context.spacing.lg,
                            vertical: context.spacing.md,
                          ),
                          decoration: BoxDecoration(
                            color: c.surfaceSubtle,
                            borderRadius: BorderRadius.circular(
                              context.radii.md,
                            ),
                            border: Border.all(color: c.border),
                          ),
                          child: Row(
                            children: [
                              Text(
                                _devIcon(link.kind.name),
                                style: context.typography.body.copyWith(
                                  color: c.textSecondary,
                                ),
                              ),
                              SizedBox(width: context.spacing.md),
                              Expanded(
                                child: Text(
                                  link.label,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.typography.mono.copyWith(
                                    color: c.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
          SizedBox(height: context.spacing.xl4),
          Row(
            children: [
              const SectionLabel('Coding agents'),
              const Spacer(),
              _DryRunToggle(),
            ],
          ),
          SizedBox(height: context.spacing.lg),
          Text(
            'Send this ticket to a coding agent to work on it.',
            style: context.typography.paragraph.copyWith(
              color: c.textSecondary,
            ),
          ),
          SizedBox(height: context.spacing.xl),
          Wrap(
            spacing: context.spacing.md,
            runSpacing: context.spacing.md,
            children: [
              for (final kind in AgentKind.values)
                AppButton.outlinedNeutral(
                  size: AppButtonSize.small,
                  onPressed: () => ref
                      .read(dispatchControllerProvider.notifier)
                      .dispatch(
                        ticketId: ticket.id,
                        kind: kind,
                        workingDir: Directory.current.path,
                        prompt:
                            'Work on ticket ${ticket.externalKey}: ${ticket.title}\n\n${ticket.body}',
                      ),
                  child: Text('▶ ${kind.displayName}'),
                ),
            ],
          ),
          SizedBox(height: context.spacing.xl3),
          AgentSessions(ticketId: ticket.id),
        ],
      ),
    );
  }

  String _devIcon(String kind) => switch (kind) {
    'branch' => '⎇',
    'pullRequest' => '⇢',
    'commit' => '⌥',
    _ => '◦',
  };
}

class _DryRunToggle extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final dry = ref.watch(dryRunAgentsProvider);
    return GestureDetector(
      onTap: () => ref.read(dryRunAgentsProvider.notifier).state = !dry,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            dry ? Icons.science_outlined : Icons.bolt,
            size: 13,
            color: dry ? c.warning : c.success,
          ),
          SizedBox(width: context.spacing.xs),
          Text(
            dry ? 'Dry-run' : 'Live CLI',
            style: context.typography.caption.copyWith(color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}
