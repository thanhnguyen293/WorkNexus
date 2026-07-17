import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_palette.dart';
import '../theme/fonts.dart';

/// App-wide appearance + language settings, persisted to drift (see `main`).
@immutable
class AppSettings {
  const AppSettings({
    this.variant = AppThemeVariant.light,
    this.surface = SurfaceStyle.outline,
    this.density = AppDensity.comfortable,
    this.companyTint = false,
    this.locale = const Locale('en'),
    this.fontFamily = kSansFont,
  });

  final AppThemeVariant variant;
  final SurfaceStyle surface;
  final AppDensity density;
  final bool companyTint;
  final Locale locale;

  /// The UI font family (a bundled or system family name). Monospace text
  /// (code / ids) always stays on [kMonoFont] regardless of this.
  final String fontFamily;

  AppSettings copyWith({
    AppThemeVariant? variant,
    SurfaceStyle? surface,
    AppDensity? density,
    bool? companyTint,
    Locale? locale,
    String? fontFamily,
  }) {
    return AppSettings(
      variant: variant ?? this.variant,
      surface: surface ?? this.surface,
      density: density ?? this.density,
      companyTint: companyTint ?? this.companyTint,
      locale: locale ?? this.locale,
      fontFamily: fontFamily ?? this.fontFamily,
    );
  }
}

/// The selectable UI fonts. Space Grotesk / Space Mono are bundled; the rest are
/// standard macOS system families (rendered via the platform font manager, with
/// a fallback to the bundled sans if unavailable).
const List<String> kFontChoices = <String>[
  kSystemFont,
  kSansFont, // Space Grotesk (default, bundled)
  'Helvetica Neue',
  'Avenir Next',
  'Georgia',
  kMonoFont, // Space Mono (bundled)
];

/// Signature for persisting a settings change (drift-backed in `main`).
typedef SettingsPersist = void Function(AppSettings settings);

/// The settings to start with — first-run defaults here, overridden in `main`
/// with the values loaded from drift so the app opens in the user's last theme.
final initialAppSettingsProvider = Provider<AppSettings>(
  (ref) => const AppSettings(),
);

/// Writes a settings change to storage. No-op by default (tests / demos);
/// overridden in `main` to persist to drift.
final settingsPersistProvider = Provider<SettingsPersist>((ref) => (_) {});

/// Holds the current [AppSettings] and exposes intent methods for the UI. Seeds
/// from [initialAppSettingsProvider] and persists every change via
/// [settingsPersistProvider], so preferences survive restarts.
class AppSettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(initialAppSettingsProvider);

  void _set(AppSettings next) {
    state = next;
    ref.read(settingsPersistProvider)(next);
  }

  void setVariant(AppThemeVariant v) => _set(state.copyWith(variant: v));
  void setSurface(SurfaceStyle s) => _set(state.copyWith(surface: s));
  void setDensity(AppDensity d) => _set(state.copyWith(density: d));
  void setCompanyTint(bool on) => _set(state.copyWith(companyTint: on));
  void setLocale(Locale l) => _set(state.copyWith(locale: l));
  void setFontFamily(String f) => _set(state.copyWith(fontFamily: f));

  void toggleCompanyTint() =>
      _set(state.copyWith(companyTint: !state.companyTint));
  void setLanguageCode(String code) =>
      _set(state.copyWith(locale: Locale(code)));
}

final appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettings>(
      AppSettingsController.new,
    );
