/// Opaque ids owned by each ToolModule (e.g. ZentaoSections.tasks =
/// SectionId('zentao.tasks')). Zero-cost; keeps core open for new tools.
extension type const SectionId(String value) {}
extension type const ViewModeId(String value) {}

/// The dashboard's pages. Members is not in any menu until the feature exists.
enum WorkspaceSection { overview, members }

/// The pages of the rail's Settings place: the app's settings and the
/// connected accounts.
enum SettingsSection { general, integrations }

enum QuickScope { all, assignedToMe, reviewRequested }
