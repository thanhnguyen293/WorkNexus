import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/error/result.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_confirm_dialog.dart';
import '../../../../core/widgets/app_expandable_card.dart';
import '../../../../core/widgets/app_segmented_tabs.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/mini_app.dart';
import '../providers/mini_app_browsing_data_controller.dart';
import '../providers/mini_app_providers.dart';
import 'mini_app_settings_app_list.dart';

/// Settings' "Mini apps" card, folded like the translation one: collapsed it
/// says how many keep running and how many there are; open it holds how many
/// keep running, whether the ones that notify keep running hidden, clearing
/// what their pages keep, and each app's own data.
class MiniAppSettingsCard extends ConsumerWidget {
  const MiniAppSettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final settings = ref.watch(appSettingsProvider);
    final controls = ref.read(appSettingsProvider.notifier);
    final apps = ref.watch(miniAppsProvider).asData?.value ?? const <MiniApp>[];
    return AppExpandableCard(
      icon: LucideIcons.appWindow300,
      title: l.miniAppSettingsTitle,
      summary: l.miniAppSettingsSummary(settings.miniAppLiveLimit, apps.length),
      sections: [
        AppExpandableCardSection(
          title: l.miniAppLiveLimitLabel,
          hint: l.miniAppLiveLimitHint,
          trailing: AppSegmentedTabs(
            tabs: [
              for (final n in kMiniAppLiveLimits)
                AppSegmentedTab(
                  label: '$n',
                  active: settings.miniAppLiveLimit == n,
                  onTap: () => controls.setMiniAppLiveLimit(n),
                ),
            ],
          ),
        ),
        AppExpandableCardSection(
          title: l.miniAppNotifyBackgroundLabel,
          hint: l.miniAppNotifyBackgroundHint,
          trailing: Switch(
            value: settings.miniAppNotifyInBackground,
            onChanged: controls.setMiniAppNotifyInBackground,
          ),
        ),
        AppExpandableCardSection(
          title: l.miniAppDataSection,
          hint: l.miniAppDataHint,
          child: _DataActions(apps: apps),
        ),
        AppExpandableCardSection(
          title: l.miniAppSettingsApps,
          hint: l.miniAppSettingsAppsHint,
          child: MiniAppSettingsAppList(apps: apps),
        ),
      ],
    );
  }
}

/// The buttons that clear the cache and all browsing data, each with what it
/// does; disabled (and said so) where the platform cannot clear.
class _DataActions extends ConsumerWidget {
  const _DataActions({required this.apps});

  final List<MiniApp> apps;

  Future<void> _clearAll(
    BuildContext context,
    MiniAppBrowsingDataController data,
  ) async {
    final l = AppL10n.of(context);
    final confirmed = await AppConfirmDialog.show(
      context,
      title: l.miniAppClearAllTitle,
      message: l.miniAppClearAllMessage,
      confirmLabel: l.miniAppClear,
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await _report(context, data.clearAll(apps));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final data = ref.watch(miniAppBrowsingDataControllerProvider.notifier);
    final running = ref.watch(miniAppBrowsingDataControllerProvider);
    final enabled = data.canClear && running == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: s.lg,
      children: [
        _Action(
          hint: l.miniAppClearCacheHint,
          button: AppButton.outlinedNeutral(
            icon: LucideIcons.broom300,
            isDisabled: !enabled,
            isLoading: running == MiniAppBrowsingDataController.cacheJob,
            onPressed: () => _report(context, data.clearCache(apps)),
            child: Text(l.miniAppClearCache),
          ),
        ),
        _Action(
          hint: l.miniAppClearAllHint,
          button: AppButton.error(
            icon: LucideIcons.trash2300,
            isDisabled: !enabled,
            isLoading: running == MiniAppBrowsingDataController.allJob,
            onPressed: () => _clearAll(context, data),
            child: Text(l.miniAppClearAll),
          ),
        ),
        if (!data.canClear)
          Text(
            l.miniAppClearUnsupported,
            style: context.typography.caption.copyWith(color: c.textTertiary),
          ),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.button, required this.hint});

  final Widget button;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      spacing: context.spacing.xl,
      children: [
        button,
        Expanded(
          child: Text(
            hint,
            style: context.typography.caption.copyWith(color: c.textSecondary),
          ),
        ),
      ],
    );
  }
}

/// Tells the user how clearing went.
Future<void> _report(BuildContext context, Future<Result<void>> job) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final l = AppL10n.of(context);
  final result = await job;
  if (messenger == null) return;
  showAppSnackOn(
    messenger,
    result.isOk ? l.miniAppCleared : l.miniAppClearFailed,
    isError: result.isErr,
  );
}

/// Clears app [app]'s site data once the user confirms, and says how it went.
Future<void> clearMiniAppSite(
  BuildContext context,
  MiniAppBrowsingDataController data,
  MiniApp app,
) async {
  final l = AppL10n.of(context);
  final confirmed = await AppConfirmDialog.show(
    context,
    title: l.miniAppClearSiteTitle(app.name),
    message: l.miniAppClearSiteMessage,
    confirmLabel: l.miniAppClear,
    destructive: true,
  );
  if (!confirmed || !context.mounted) return;
  await _report(context, data.clearSite(app));
}
