import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/agent_event.dart';
import '../../../../core/domain/value_objects/agent_kind.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../agents/presentation/agent_providers.dart';

/// The list of coding-agent sessions dispatched for a ticket (dev tab).
class AgentSessions extends ConsumerWidget {
  const AgentSessions({super.key, required this.ticketId});
  final String ticketId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final sessions = ref.watch(agentSessionsProvider(ticketId));
    return sessions.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final s in list.reversed)
              Container(
                margin: EdgeInsets.only(bottom: context.spacing.lg),
                padding: EdgeInsets.all(context.spacing.lg),
                decoration: BoxDecoration(
                  color: c.surfaceSubtle,
                  borderRadius: BorderRadius.circular(context.radii.md),
                  border: Border.all(color: c.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          s.agentKind.displayName,
                          style: context.typography.monoStrong.copyWith(
                            color: c.textPrimary,
                          ),
                        ),
                        SizedBox(width: context.spacing.md),
                        _StatusPill(s.status),
                      ],
                    ),
                    SizedBox(height: context.spacing.md),
                    for (final line in _eventLines(s.events).take(6))
                      Padding(
                        padding: EdgeInsets.only(bottom: context.spacing.xxs),
                        child: Text(
                          line,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.typography.mono.copyWith(
                            color: c.textTertiary,
                          ),
                        ),
                      ),
                    if (s.resultSummary != null) ...[
                      SizedBox(height: context.spacing.xs),
                      Text(
                        s.resultSummary!,
                        style: context.typography.bodySm.copyWith(
                          color: c.textPrimary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  List<String> _eventLines(List<AgentEvent> events) => [
    for (final e in events) _line(e),
  ];

  String _line(AgentEvent e) => switch (e) {
    AgentSessionStarted(:final sessionId) => '· session ${sessionId ?? ''}',
    AgentTextDelta(:final text) => text,
    AgentMessage(:final text) => '› $text',
    AgentToolStarted(:final toolName) => '⚙ $toolName…',
    AgentToolCompleted(:final toolName) => '✓ $toolName',
    AgentFileChanged(:final path) => '± $path',
    AgentPlanUpdated() => 'plan updated',
    AgentRetry(:final attempt) => 'retry $attempt',
    AgentErrorEvent(:final message) => '⛔ $message',
    AgentResult() => '■ done',
  };
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.status);
  final AgentSessionStatus status;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pill = switch (status) {
      AgentSessionStatus.running => c.warning,
      AgentSessionStatus.succeeded => c.success,
      AgentSessionStatus.failed => c.error,
      _ => c.textTertiary,
    };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.sm,
        vertical: context.spacing.xxs,
      ),
      decoration: BoxDecoration(
        color: c.mixT(pill, 0.15),
        borderRadius: BorderRadius.circular(context.radii.xs),
      ),
      child: Text(
        status.name,
        style: context.typography.captionSm.copyWith(
          fontWeight: FontWeight.w600,
          color: pill,
        ),
      ),
    );
  }
}
