import 'package:flutter/widgets.dart';

import '../../core/widgets/app_page.dart';
import '../../features/app_update/presentation/widgets/update_settings_card.dart';
import '../../features/connections/presentation/widgets/local_cache_card.dart';
import '../../features/mini_apps/presentation/widgets/mini_app_settings_card.dart';
import '../../features/translation/presentation/widgets/translation_settings_card.dart';
import '../../l10n/app_localizations.dart';

/// The workspace's Settings page: the app's own settings, gathered from the
/// features that own them. Connected accounts are on the Integrations page.
class WorkspaceSettingsPage extends StatelessWidget {
  const WorkspaceSettingsPage({super.key});

  @override
  Widget build(BuildContext context) => AppPage(
    title: AppL10n.of(context).settings,
    children: const [
      TranslationSettingsCard(),
      MiniAppSettingsCard(),
      UpdateSettingsCard(),
      LocalCacheCard(),
    ],
  );
}
