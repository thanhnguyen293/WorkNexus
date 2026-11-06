import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dialog_frame.dart';
import '../../../../core/widgets/app_dropdown.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/cookie_source.dart';
import '../providers/cookie_import_controller.dart';
import '../util/cookie_browser_name.dart';
import 'cookie_import_feedback.dart';
import 'cookie_site_picker.dart';

/// Imports cookies from a browser: pick the browser profile, then the sites
/// (the mini apps' ones are picked to begin with). Only those sites' cookies
/// go into the mini apps.
///
/// Opened from one mini app, it is about that app's [site]: picked alone and
/// listed first, from the [source] it was last imported from, if any.
class CookieImportDialog extends ConsumerStatefulWidget {
  const CookieImportDialog({super.key, this.site, this.source});

  final String? site;
  final CookieSource? source;

  static Future<void> show(
    BuildContext context, {
    String? site,
    CookieSource? source,
  }) => showDialog<void>(
    context: context,
    builder: (_) => CookieImportDialog(site: site, source: source),
  );

  @override
  ConsumerState<CookieImportDialog> createState() => _CookieImportDialogState();
}

class _CookieImportDialogState extends ConsumerState<CookieImportDialog> {
  CookieSource? _source;

  /// The sites picked for [_source]; null until its sites are read.
  Set<String>? _picked;
  bool _importing = false;

  void _choose(CookieSource source) => setState(() {
    _source = source;
    _picked = null;
  });

  Future<void> _import(CookieSource source, Set<String> sites) async {
    final navigator = Navigator.of(context);
    setState(() => _importing = true);
    final job = ref.read(cookieImportsProvider.notifier).import(source, sites);
    await reportCookieImport(context, source, job);
    final result = await job;
    if (!mounted) return;
    if (result.isOk) {
      navigator.pop();
    } else {
      setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final l = AppL10n.of(context);
    final sources = ref.watch(cookieSourcesProvider);
    final list = sources.asData?.value ?? const <CookieSource>[];
    final source =
        _source ??
        (list.contains(widget.source) ? widget.source : list.firstOrNull);
    final sites = source == null
        ? null
        : ref.watch(cookieSitesProvider(source));
    final focus = widget.site;
    final loaded = switch (sites?.asData?.value) {
      final all? when focus != null => [
        ...all.where((s) => s.site == focus),
        ...all.where((s) => s.site != focus),
      ],
      final all => all,
    };
    if (loaded != null) {
      _picked ??= {
        for (final site in loaded)
          if (focus == null ? site.usedByMiniApp : site.site == focus)
            site.site,
      };
    }
    final picked = _picked ?? const <String>{};
    return AppDialogFrame(
      title: l.miniAppCookiesDialogTitle,
      leadingIcon: LucideIcons.cookie300,
      maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      actions: [
        const Spacer(),
        AppButton.textNeutral(
          size: AppButtonSize.small,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        AppButton.filled(
          size: AppButtonSize.small,
          isLoading: _importing,
          onPressed: source == null || picked.isEmpty || _importing
              ? null
              : () => _import(source, picked),
          child: Text(l.miniAppCookiesImportCount(picked.length)),
        ),
      ],
      child: Padding(
        padding: EdgeInsets.fromLTRB(s.xl3, 0, s.xl3, s.xl3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: s.xl,
          children: [
            if (sources.isLoading)
              const _Spinner()
            else if (source == null)
              _Note(l.miniAppCookiesNoBrowser)
            else ...[
              _SourcePicker(sources: list, value: source, onChanged: _choose),
              if (sites == null || sites.isLoading) ...[
                if (source.browser.isChromium)
                  _Note(
                    l.miniAppCookiesKeychainHint(
                      cookieBrowserName(source.browser),
                    ),
                  ),
                const _Spinner(),
              ] else if (sites.error case final Failure failure)
                _ReadError(source: source, failure: failure)
              else
                Flexible(
                  child: CookieSitePicker(
                    sites: loaded ?? const [],
                    picked: picked,
                    onChanged: (next) => setState(() => _picked = next),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SourcePicker extends StatelessWidget {
  const _SourcePicker({
    required this.sources,
    required this.value,
    required this.onChanged,
  });

  final List<CookieSource> sources;
  final CookieSource value;
  final ValueChanged<CookieSource> onChanged;

  static String _label(CookieSource source) {
    final browser = cookieBrowserName(source.browser);
    return source.profileName == browser
        ? browser
        : '$browser · ${source.profileName}';
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: context.spacing.sm,
    children: [
      Text(
        AppL10n.of(context).miniAppCookiesBrowserLabel,
        style: context.typography.captionStrong.copyWith(
          color: context.colors.textSecondary,
        ),
      ),
      AppDropdown<CookieSource>(
        value: value,
        values: sources,
        labelOf: _label,
        onChanged: onChanged,
      ),
    ],
  );
}

/// Why the profile's cookies could not be read, and the way past it.
class _ReadError extends ConsumerWidget {
  const _ReadError({required this.source, required this.failure});

  final CookieSource source;
  final Failure failure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: context.spacing.md,
      children: [
        _Note(
          failure is AuthFailure
              ? cookieFailureMessage(l, source, failure)
              : l.miniAppCookiesReadFailed,
          error: true,
        ),
        Row(
          spacing: context.spacing.md,
          children: [
            if (needsFullDiskAccess(source, failure))
              AppButton.outlinedNeutral(
                size: AppButtonSize.small,
                icon: LucideIcons.shieldCheck300,
                onPressed: openFullDiskAccessSettings,
                child: Text(l.miniAppCookiesOpenPrivacy),
              ),
            AppButton.outlinedNeutral(
              size: AppButtonSize.small,
              icon: LucideIcons.refreshCw300,
              onPressed: () => ref.invalidate(cookieSitesProvider(source)),
              child: Text(l.miniAppCookiesRetry),
            ),
          ],
        ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text, {this.error = false});

  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Text(
      text,
      style: context.typography.caption.copyWith(
        color: error ? c.error : c.textSecondary,
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: EdgeInsets.all(context.spacing.xl),
      child: SizedBox.square(
        dimension: context.sizes.iconLg,
        child: const CircularProgressIndicator(),
      ),
    ),
  );
}
