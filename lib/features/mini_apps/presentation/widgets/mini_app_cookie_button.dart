import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/mini_app.dart';
import '../../domain/value_objects/cookie_site_of.dart';
import '../providers/cookie_import_controller.dart';
import '../providers/mini_app_browser_controller.dart';
import '../util/cookie_browser_name.dart';
import 'cookie_import_dialog.dart';

/// A mini app's toolbar button to sign it in with a browser's cookies: opens
/// the import on this app's site, from the browser it last came from. Tinted
/// once those cookies are gone; each page load checks again, as that is when
/// a site signs one out. Hidden where the web view takes no cookies.
class MiniAppCookieButton extends ConsumerWidget {
  const MiniAppCookieButton({super.key, required this.app});

  final MiniApp app;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(miniAppBrowserProvider(app.id).select((s) => s.loading), (
      was,
      loading,
    ) {
      if (was == true && !loading) ref.invalidate(cookieImportsProvider);
    });
    final host = Uri.tryParse(app.url)?.host ?? '';
    final imports = ref.watch(cookieImportsProvider);
    if (host.isEmpty || !ref.read(cookieImportsProvider.notifier).canImport) {
      return const SizedBox.shrink();
    }
    final l = AppL10n.of(context);
    final site = cookieSiteOf(host);
    final state = imports.asData?.value
        .where((i) => i.import.site == site)
        .firstOrNull;
    final source = state?.import.source;
    final expired = (state?.expired ?? false) && source != null;
    return AppIconButton(
      icon: LucideIcons.cookie300,
      color: expired ? context.colors.warning : null,
      tooltip: expired
          ? l.miniAppCookiesExpiredTooltip(cookieBrowserName(source.browser))
          : l.miniAppCookiesImport,
      onPressed: () =>
          CookieImportDialog.show(context, site: site, source: source),
    );
  }
}
