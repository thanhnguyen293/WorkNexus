/// Opaque ids owned by each ToolModule (e.g. ZentaoSections.tasks =
/// SectionId('zentao.tasks')). Zero-cost; keeps core open for new tools.
extension type const SectionId(String value) {}
extension type const ViewModeId(String value) {}

enum WorkspaceSection { overview, members, integrations, settings }

enum QuickScope { all, assignedToMe, reviewRequested }
