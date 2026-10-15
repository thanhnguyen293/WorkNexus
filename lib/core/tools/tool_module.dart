import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../../l10n/app_localizations.dart';
import '../domain/entities/account.dart';
import '../domain/entities/ticket.dart';
import '../domain/value_objects/provider_type.dart';
import '../navigation/app_nav_state.dart';

export '../navigation/nav_ids.dart' show SectionId, ViewModeId;

enum ScopeKind { project, product, repository, library, conversation, none }

class ToolViewMode {
  const ToolViewMode({
    required this.id,
    required this.label,
    required this.icon,
  });

  final ViewModeId id;
  final String Function(AppL10n) label;
  final IconData icon;
}

class ToolSection {
  const ToolSection({
    required this.id,
    required this.label,
    required this.icon,
    required this.scopeKind,
    this.viewModes = const [],
    this.available = true,
    this.unreadCount,
  });

  final SectionId id;
  final String Function(AppL10n) label;
  final IconData icon;
  final ScopeKind scopeKind;
  final List<ToolViewMode> viewModes;
  final bool available;
  final ProviderListenable<int>? unreadCount;
}

class ToolMetrics {
  const ToolMetrics({
    required this.primaryCount,
    required this.primaryLabel,
    this.secondaryCount,
    this.secondaryLabel,
  });

  final int primaryCount;
  final String Function(AppL10n) primaryLabel;
  final int? secondaryCount;
  final String Function(AppL10n)? secondaryLabel;
}

/// A provider integration the shell can host. Implemented once per tool in
/// `tools/<tool>/<tool>_module.dart`; registered in `app/tool_registry.dart`.
abstract class ToolModule {
  const ToolModule();

  ProviderType get providerType;

  /// Default section for this module (e.g. `SectionId('zentao.tasks')`).
  SectionId get defaultSection => const SectionId('default');

  /// Sections supported by this module.
  List<ToolSection> get sections => const [];

  /// Role label for this tool module on the workspace overview card (e.g. "Project management").
  String Function(AppL10n) get roleLabel =>
      (l10n) => '';

  /// Builds the navigation pane (L3/L4) for this tool account at [location].
  Widget buildNavPane(
    BuildContext context,
    Account account,
    ToolLocation location,
  ) => throw UnimplementedError(
    'buildNavPane not implemented for $providerType',
  );

  /// Builds the viewport section (L5) for this tool account at [location].
  Widget buildSection(
    BuildContext context,
    Account account,
    ToolLocation location,
  ) => throw UnimplementedError(
    'buildSection not implemented for $providerType',
  );

  /// Metrics for the Overview card. Reads only the local DB.
  ProviderListenable<AsyncValue<ToolMetrics>> metrics(Account account) =>
      throw UnimplementedError('metrics not implemented for $providerType');

  /// Narrows [tickets] (every cached ticket) to the ones the section at
  /// [location] shows before the user's filters — the open project, product or
  /// execution, and for a paged board what its views have loaded. Called from a
  /// provider, so what it watches through [ref] rebuilds the board. The default
  /// keeps every ticket.
  List<Ticket> scopeTickets(
    Ref ref,
    ToolLocation location,
    List<Ticket> tickets,
  ) => tickets;

  /// External web deep link for [location] (e.g. ↗ to open in browser).
  Uri? webUrl(Account account, ToolLocation location) => null;

  /// Builds the slide-over detail body for [ticket] (only called when
  /// `ticket.providerType == providerType`), or null to use the standard tabbed panel.
  Widget? buildDetail(
    BuildContext context,
    Ticket ticket, {
    VoidCallback? onClose,
  }) => null;

  /// Builds action buttons for [ticket] in the detail panel, or null if none.
  Widget? buildActions(BuildContext context, Ticket ticket) => null;

  /// Builds extra header actions or badges (e.g. ZenTao ParentTaskLink), or null if none.
  Widget? buildDetailHeaderExtras(BuildContext context, Ticket ticket) => null;

  /// Builds a provider-specific status indicator widget (e.g. ZenTao BugStatusStrip), or null if none.
  Widget? buildStatusStrip(BuildContext context, Ticket ticket) => null;

  /// Builds provider-specific effort tracking (e.g. TaskEffortBar), or null if none.
  Widget? buildDetailEffort(BuildContext context, Ticket ticket) => null;

  /// Builds provider-specific subtasks list (e.g. SubtaskList), or null if none.
  Widget? buildDetailSubtasks(BuildContext context, Ticket ticket) => null;

  /// Builds provider-specific attachments widget (e.g. BugAttachments), or null if none.
  Widget? buildDetailAttachments(BuildContext context, Ticket ticket) => null;

  /// Builds provider-specific metadata card/sidebar sections, or null if none.
  Widget? buildDetailSidebar(BuildContext context, Ticket ticket) => null;
}
