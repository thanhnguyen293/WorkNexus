import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/util/relative_time.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/tinted_pill.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/cookie_import.dart';
import '../providers/cookie_import_controller.dart';
import '../util/cookie_browser_name.dart';
import 'cookie_import_dialog.dart';
import 'cookie_import_feedback.dart';

/// Settings' imported cookies: a button to import from a browser, then each
/// imported site with where it came from, whether its sign-in is still there
/// and a way to import it again.
class MiniAppCookieImportsSection extends ConsumerWidget {
  const MiniAppCookieImportsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final controller = ref.watch(cookieImportsProvider.notifier);
    final imports = ref.watch(cookieImportsProvider).asData?.value ?? const [];
    final caption = context.typography.caption;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: context.spacing.md,
      children: [
        AppButton.outlinedNeutral(
          icon: LucideIcons.cookie300,
          isDisabled: !controller.canImport,
          onPressed: () => CookieImportDialog.show(context),
          child: Text(l.miniAppCookiesImport),
        ),
        if (!controller.canImport)
          Text(
            l.miniAppCookiesUnsupported,
            style: caption.copyWith(color: c.textTertiary),
          )
        else if (imports.isEmpty)
          Text(
            l.miniAppCookiesEmpty,
            style: caption.copyWith(color: c.textTertiary),
          )
        else
          for (final state in imports) _ImportRow(state: state),
      ],
    );
  }
}

class _ImportRow extends ConsumerStatefulWidget {
  const _ImportRow({required this.state});

  final CookieImportState state;

  @override
  ConsumerState<_ImportRow> createState() => _ImportRowState();
}

class _ImportRowState extends ConsumerState<_ImportRow> {
  bool _busy = false;

  Future<void> _reimport() async {
    final state = widget.state;
    setState(() => _busy = true);
    await reportCookieImport(
      context,
      state.import.source,
      ref.read(cookieImportsProvider.notifier).reimport(state),
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final state = widget.state;
    final import = state.import;
    final when = formatWhen(
      context,
      import.importedAt.toLocal(),
      format: ref.watch(appSettingsProvider.select((s) => s.dateFormat)),
    );
    return Row(
      spacing: s.lg,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: s.xxs,
            children: [
              Row(
                spacing: s.md,
                children: [
                  Flexible(
                    child: Text(
                      import.site,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.typography.bodyStrong.copyWith(
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                  Tooltip(
                    message: state.expired ? l.miniAppCookiesExpiredHint : '',
                    child: TintedPill(
                      color: state.expired ? c.warning : c.success,
                      label: state.expired
                          ? l.miniAppCookiesExpired
                          : l.miniAppCookiesActive,
                    ),
                  ),
                ],
              ),
              Text(
                l.miniAppCookiesFrom(
                  cookieBrowserName(import.source.browser),
                  import.source.profileName,
                  when,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.typography.caption.copyWith(
                  color: c.textTertiary,
                ),
              ),
            ],
          ),
        ),
        if (state.expired)
          AppButton.filled(
            size: AppButtonSize.small,
            icon: LucideIcons.refreshCw300,
            isLoading: _busy,
            onPressed: _busy ? null : _reimport,
            child: Text(l.miniAppCookiesReimport),
          )
        else
          AppIconButton(
            icon: LucideIcons.refreshCw300,
            tooltip: l.miniAppCookiesReimport,
            isLoading: _busy,
            onPressed: _busy ? null : _reimport,
          ),
        AppIconButton(
          icon: LucideIcons.x300,
          tooltip: l.miniAppCookiesForget,
          onPressed: _busy
              ? null
              : () => ref
                    .read(cookieImportsProvider.notifier)
                    .forget(import.site),
        ),
      ],
    );
  }
}
