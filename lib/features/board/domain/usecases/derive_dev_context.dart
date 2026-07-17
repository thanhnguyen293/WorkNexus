import '../../../../core/domain/entities/agent_session.dart';
import '../../../../core/domain/entities/dev_link.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/agent_kind.dart';

/// A running/finished agent associated with a ticket's dev work.
class DevAgentInfo {
  const DevAgentInfo({
    required this.name,
    required this.running,
    required this.labelKey,
  });

  final String name;
  final bool running;

  /// A short status word shown after the agent name (e.g. 'coding', 'done',
  /// 'translating', 'reviewed').
  final String labelKey;
}

/// The compact dev context shown on a board card and the sidebar activity feed.
class DevContext {
  const DevContext({this.branch, this.pr, this.commit, this.agent});

  final String? branch;
  final String? pr;
  final String? commit;
  final DevAgentInfo? agent;

  bool get hasDev => branch != null || pr != null || commit != null;
}

/// Builds the card's dev row + agent chip from **real** linked data:
/// the ticket's [DevLink]s (branch/PR/commit) and [AgentSession]s (dispatched
/// coding agents), plus the live translation state. Returns an empty context
/// when a ticket has no linked code or agent activity — nothing is invented.
class DeriveDevContext {
  const DeriveDevContext();

  DevContext call(
    Ticket t, {
    List<DevLink> links = const [],
    List<AgentSession> sessions = const [],
    bool translationLoading = false,
  }) {
    String? branch, pr, commit;
    for (final l in links) {
      switch (l.kind) {
        case DevLinkKind.branch:
          branch ??= l.label;
        case DevLinkKind.pullRequest:
          pr ??= l.label;
        case DevLinkKind.commit:
          commit ??= l.label;
        case DevLinkKind.repo:
          break;
      }
    }

    DevAgentInfo? agent;
    if (translationLoading) {
      agent = const DevAgentInfo(
        name: 'OpenCode',
        running: true,
        labelKey: 'translating',
      );
    } else if (sessions.isNotEmpty) {
      // Most recent session drives the chip.
      final s = sessions.last;
      final label = switch (s.status) {
        AgentSessionStatus.running => 'coding',
        AgentSessionStatus.succeeded => 'done',
        AgentSessionStatus.failed => 'failed',
        AgentSessionStatus.cancelled => 'cancelled',
        AgentSessionStatus.queued => 'queued',
      };
      // Only surface active/finished work on the card (skip queued/cancelled).
      if (s.status == AgentSessionStatus.running ||
          s.status == AgentSessionStatus.succeeded ||
          s.status == AgentSessionStatus.failed) {
        agent = DevAgentInfo(
          name: s.agentKind.displayName,
          running: s.status == AgentSessionStatus.running,
          labelKey: label,
        );
      }
    }

    return DevContext(branch: branch, pr: pr, commit: commit, agent: agent);
  }
}
