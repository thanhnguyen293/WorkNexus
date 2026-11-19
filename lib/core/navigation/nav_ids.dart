/// Opaque ids owned by each ToolModule (e.g. ZentaoSections.tasks =
/// SectionId('zentao.tasks')). Zero-cost; keeps core open for new tools.
extension type const SectionId(String value) {}
extension type const ViewModeId(String value) {}

/// The dashboard's pages. Members is not in any menu until the feature exists.
enum WorkspaceSection { overview, members }

/// The pages of the rail's Settings place: one per group of the app's
/// settings, then the connected accounts.
enum SettingsSection {
  general,
  translation,
  miniApps,
  panicSwitch,
  integrations,
}

enum QuickScope { all, assignedToMe, reviewRequested }
