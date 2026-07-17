/// A coding agent WorkNexus can dispatch a ticket to. `cliName` is the default
/// executable resolved on PATH; the resolved absolute path is user-overridable.
enum AgentKind {
  claudeCode(cliName: 'claude', displayName: 'Claude Code'),
  codex(cliName: 'codex', displayName: 'Codex'),
  opencode(cliName: 'opencode', displayName: 'OpenCode');

  const AgentKind({required this.cliName, required this.displayName});

  final String cliName;
  final String displayName;
}

/// How autonomous a dispatched agent run may be. Each adapter maps this onto
/// its native sandbox/permission model (see plan §"CodingAgentAdapter").
enum AgentAutonomy { readOnly, edit, full }

/// Lifecycle of an [AgentSession].
enum AgentSessionStatus { queued, running, succeeded, failed, cancelled }
