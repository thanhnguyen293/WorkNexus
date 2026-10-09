import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/platform/desktop_app_lifecycle.dart';
import '../core/settings/app_settings.dart';
import '../core/theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import 'shell/app_shell.dart';

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
    final settings = ref.watch(appSettingsProvider);
    return MaterialApp(
      onGenerateTitle: (context) => AppL10n.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      locale: settings.locale,
      localizationsDelegates: const [
        AppL10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppL10n.supportedLocales,
      theme: buildAppTheme(
        variant: settings.variant,
        surface: settings.surface,
        density: settings.density,
        fontFamily: settings.fontFamily,
        componentRadius: settings.componentRadius,
        accentColorValue: settings.accentColorValue,
      ),
      home: const AppShell(),
    );
  }
}
