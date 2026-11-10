import '../../../../core/domain/entities/account.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../l10n/app_localizations.dart';

/// The search field's placeholder for the screen [nav] is on: the tool of the
/// account on screen, else the workspace.
String searchPlaceholder(AppL10n l, AppNavState nav, List<Account> accounts) =>
    switch (nav.rail) {
      WorkspaceTarget() ||
      ChatTarget() ||
      SettingsTarget() => l.searchContextWorkspace,
      AccountTarget(:final accountId) => switch (accounts
          .where((a) => a.id == accountId)
          .firstOrNull) {
        final account? => l.searchContextTool(account.providerType.displayName),
        null => l.searchContextWorkspace,
      },
    };
