import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_palette.dart';
import '../theme/app_radii.dart';
import '../theme/fonts.dart';

/// How the ticket detail panel arranges its body.
enum DetailLayout {
  /// Content beside a fixed-width metadata sidebar (wider panel).
  twoPane,

  /// A centered, single-column reading layout with metadata stacked below.
  document,
}

/// App-wide appearance + language settings, persisted to drift (see `main`).
@immutable
class AppSettings {
  const AppSettings({
    this.variant = AppThemeVariant.light,
    this.surface = SurfaceStyle.outline,
    this.density = AppDensity.comfortable,
    this.detailLayout = DetailLayout.twoPane,
    this.companyTint = false,
    this.locale = const Locale('en'),
    this.fontFamily = kSansFont,
    this.componentRadius = kComponentRadiusDefault,
    this.accentColorValue,
    this.pinnedProjects = const <String>{},
  });

  final AppThemeVariant variant;
  final SurfaceStyle surface;
  final AppDensity density;
  final DetailLayout detailLayout;
  final bool companyTint;
  final Locale locale;

  /// Pinned ZenTao project keys (`"accountId:productId"`) surfaced at the top of
  /// the sources tree. Persisted so pins survive restarts.
  final Set<String> pinnedProjects;

  /// The user-chosen app primary/accent color (ARGB int), or `null` to use the
  /// active theme variant's built-in accent.
  final int? accentColorValue;

  /// The UI font family (a bundled or system family name). Monospace text
  /// (code / ids) always stays on [kMonoFont] regardless of this.
  final String fontFamily;

  /// User-chosen corner radius (logical px) for design-system components, driven
  /// by the settings slider. Clamped to [kComponentRadiusMin]..[kComponentRadiusMax].
  final double componentRadius;

  AppSettings copyWith({
    AppThemeVariant? variant,
    SurfaceStyle? surface,
    AppDensity? density,
    DetailLayout? detailLayout,
    bool? companyTint,
    Locale? locale,
    String? fontFamily,
    double? componentRadius,
    Set<String>? pinnedProjects,
    // Sentinel so `null` can be passed explicitly to reset to the theme accent.
    Object? accentColorValue = _unset,
  }) {
    return AppSettings(
      variant: variant ?? this.variant,
      surface: surface ?? this.surface,
      density: density ?? this.density,
      detailLayout: detailLayout ?? this.detailLayout,
      companyTint: companyTint ?? this.companyTint,
      locale: locale ?? this.locale,
      fontFamily: fontFamily ?? this.fontFamily,
      componentRadius: componentRadius ?? this.componentRadius,
      pinnedProjects: pinnedProjects ?? this.pinnedProjects,
      accentColorValue: identical(accentColorValue, _unset)
          ? this.accentColorValue
          : accentColorValue as int?,
    );
  }
}

/// Sentinel marking "argument not passed" in [AppSettings.copyWith], so a real
/// `null` can distinguish "reset to theme accent".
const Object _unset = Object();

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
  void setDetailLayout(DetailLayout l) => _set(state.copyWith(detailLayout: l));
  void setCompanyTint(bool on) => _set(state.copyWith(companyTint: on));
  void setLocale(Locale l) => _set(state.copyWith(locale: l));
  void setFontFamily(String f) => _set(state.copyWith(fontFamily: f));
  void setComponentRadius(double r) =>
      _set(state.copyWith(componentRadius: snapComponentRadius(r)));

  /// Sets the app primary color; pass `null` to fall back to the theme accent.
  void setAccentColor(int? value) =>
      _set(state.copyWith(accentColorValue: value));

  /// Pins/unpins a ZenTao project by its `"accountId:productId"` [key].
  void togglePinnedProject(String key) {
    final next = Set<String>.of(state.pinnedProjects);
    next.contains(key) ? next.remove(key) : next.add(key);
    _set(state.copyWith(pinnedProjects: next));
  }

  void toggleCompanyTint() =>
      _set(state.copyWith(companyTint: !state.companyTint));
  void setLanguageCode(String code) =>
      _set(state.copyWith(locale: Locale(code)));
}

final appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettings>(
      AppSettingsController.new,
    );
