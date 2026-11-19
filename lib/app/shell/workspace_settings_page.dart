import 'package:flutter/widgets.dart';

import '../../core/widgets/app_expandable_card.dart';
import '../../core/widgets/app_page.dart';
import '../../features/app_update/presentation/widgets/update_settings_card.dart';
import '../../features/connections/presentation/widgets/local_cache_card.dart';
import '../../features/mini_apps/presentation/widgets/mini_app_settings_card.dart';
import '../../features/panic_switch/presentation/widgets/panic_switch_settings_card.dart';
import '../../features/translation/presentation/widgets/translation_settings_card.dart';
import '../../l10n/app_localizations.dart';

/// The Settings place's "General" page: updates and the local cache.
class WorkspaceSettingsPage extends StatelessWidget {
  const WorkspaceSettingsPage({super.key});

  @override
  Widget build(BuildContext context) => AppPage(
    title: AppL10n.of(context).settingsGeneral,
    children: const [UpdateSettingsCard(), LocalCacheCard()],
  );
}

/// A Settings page holding one feature's card, shown open and without its
/// own header: the page title names it.
class SettingsCardPage extends StatelessWidget {
  const SettingsCardPage({super.key, required this.title, required this.card});

  final String title;
  final Widget card;

  /// The page for [section]'s card.
  static Widget translation(BuildContext context) => SettingsCardPage(
    title: AppL10n.of(context).translationSection,
    card: const TranslationSettingsCard(),
  );

  static Widget miniApps(BuildContext context) => SettingsCardPage(
    title: AppL10n.of(context).miniAppSettingsTitle,
    card: const MiniAppSettingsCard(),
  );

  static Widget panicSwitch(BuildContext context) => SettingsCardPage(
    title: AppL10n.of(context).panicSwitchTitle,
    card: const PanicSwitchSettingsCard(),
  );

  @override
  Widget build(BuildContext context) => AppPage(
    title: title,
    children: [AppExpandableCardScope(child: card)],
  );
}
