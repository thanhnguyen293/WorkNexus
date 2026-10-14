import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart'
    show FlutterQuillLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/platform/desktop_app_lifecycle.dart';
import '../core/settings/app_settings.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/celebration_overlay.dart';
import '../l10n/app_localizations.dart';
import 'shell/app_shell.dart';

/// The light and dark [ThemeData] for the current appearance settings.
///
/// Built from the appearance fields only (a record, so it compares by value):
/// any other setting — the sidebar width, a pin, a chat slider — leaves these
/// `ThemeData` instances untouched, and so neither re-themes the tree nor
/// plays the theme transition. The theme extensions compare by identity, so
/// reusing the instances is what keeps `Theme.of` dependents quiet.
final appThemesProvider = Provider<({ThemeData light, ThemeData dark})>((ref) {
  final a = ref.watch(
    appSettingsProvider.select(
      (s) => (
        variant: s.variant,
        followsSystem: s.themeFollowsSystem,
        surface: s.surface,
        density: s.density,
        fontFamily: s.fontFamily,
        componentRadius: s.componentRadius,
        accentColorValue: s.accentColorValue,
      ),
    ),
  );
  ThemeData themeFor(AppThemeVariant variant) => buildAppTheme(
    variant: variant,
    surface: a.surface,
    density: a.density,
    fontFamily: a.fontFamily,
    componentRadius: a.componentRadius,
    accentColorValue: a.accentColorValue,
  );
  return (
    // Following the OS, Flutter swaps light/dark live as the system does;
    // otherwise the picked variant is the only theme.
    light: themeFor(a.followsSystem ? AppThemeVariant.light : a.variant),
    dark: themeFor(AppThemeVariant.dark),
  );
});

/// Root application widget. Rebuilds the theme when appearance settings change
/// and drives the locale from [appSettingsProvider].
class WorkNexusApp extends ConsumerWidget {
  const WorkNexusApp({super.key, this.lifecycle});

  final DesktopAppLifecycle? lifecycle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The native tray menu does not rebuild with Flutter. Update its labels
    // separately when the app locale changes; the initial locale is set in main.
    ref.listen(appSettingsProvider.select((settings) => settings.locale), (
      _,
      locale,
    ) {
      final activeLifecycle = lifecycle;
      if (activeLifecycle != null) {
        unawaited(activeLifecycle.updateLocale(locale));
      }
    });
    final locale = ref.watch(appSettingsProvider.select((s) => s.locale));
    final followsSystem = ref.watch(
      appSettingsProvider.select((s) => s.themeFollowsSystem),
    );
    final themes = ref.watch(appThemesProvider);
    return MaterialApp(
      onGenerateTitle: (context) => AppL10n.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      locale: locale,
      localizationsDelegates: const [
        AppL10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        // The rich-text editor's toolbar tooltips and dialogs.
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: AppL10n.supportedLocales,
      theme: themes.light,
      darkTheme: themes.dark,
      themeMode: followsSystem ? ThemeMode.system : ThemeMode.light,
      // Above the navigator, so a show also plays over an open dialog.
      builder: (context, child) =>
          CelebrationOverlay(child: child ?? const SizedBox.shrink()),
      home: const AppShell(),
    );
  }
}
