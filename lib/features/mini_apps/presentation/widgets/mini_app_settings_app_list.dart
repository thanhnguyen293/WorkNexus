import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/mini_app.dart';
import '../providers/mini_app_browsing_data_controller.dart';
import 'mini_app_dialog.dart';
import 'mini_app_icon.dart';
import 'mini_app_settings_card.dart';

/// The mini apps card's list of apps, in rail order: each one's site, a way to
/// edit it (and its permissions) and to clear what it keeps.
class MiniAppSettingsAppList extends StatelessWidget {
  const MiniAppSettingsAppList({super.key, required this.apps});

  final List<MiniApp> apps;

  @override
  Widget build(BuildContext context) {
    if (apps.isEmpty) {
      return Text(
        AppL10n.of(context).miniAppSettingsEmpty,
        style: context.typography.caption.copyWith(
          color: context.colors.textTertiary,
        ),
      );
    }
    return Column(children: [for (final app in apps) _AppRow(app: app)]);
  }
}

class _AppRow extends ConsumerWidget {
  const _AppRow({required this.app});

  final MiniApp app;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final data = ref.watch(miniAppBrowsingDataControllerProvider.notifier);
    final running = ref.watch(miniAppBrowsingDataControllerProvider);
    final host = Uri.tryParse(app.url)?.host ?? app.url;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: s.xs),
      child: Row(
        spacing: s.lg,
        children: [
          // The fallback letter takes this ink.
          DefaultTextStyle.merge(
            style: context.typography.body.copyWith(color: c.textSecondary),
            child: MiniAppIcon(
              name: app.name,
              iconPath: app.iconPath,
              size: context.sizes.iconLg,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.bodyStrong.copyWith(
                    color: c.textPrimary,
                  ),
                ),
                Text(
                  host,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.caption.copyWith(
                    color: c.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          AppIconButton(
            icon: LucideIcons.pencil300,
            tooltip: l.miniAppEdit,
            onPressed: () => MiniAppDialog.show(context, existing: app),
          ),
          AppIconButton(
            icon: LucideIcons.eraser300,
            tooltip: data.canClear
                ? l.miniAppClearSite
                : l.miniAppClearUnsupported,
            isLoading: running == app.id,
            onPressed: data.canClear && running == null
                ? () => clearMiniAppSite(context, data, app)
                : null,
          ),
        ],
      ),
    );
  }
}
