import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_palette.dart';
import '../theme/app_radii.dart';
import '../theme/fonts.dart';
import '../util/translation_languages.dart';
import 'chat_appearance.dart';
import 'pinned_execution.dart';

/// How the ticket detail panel arranges its body.
enum DetailLayout {
  /// Content beside a fixed-width metadata sidebar (wider panel).
  twoPane,

  /// A centered, single-column reading layout with metadata stacked below.
  document,
}

/// How a concrete timestamp (older than an hour) renders its date part. The time
/// is always 24h `HH:mm`, and very recent times still show "just now" / "x min
/// ago" regardless of this.
enum DateDisplayFormat {
  /// `2026-05-26 10:28`
  iso,

  /// `26/05/2026 10:28`
  dmy,

  /// Locale-aware long form: `May 26, 2026 10:28` (en) / `26 thg 5, 2026 10:28`
  /// (vi).
  long,
}

/// Default width (logical px) of the left sidebar, matching the historical
/// fixed width before it became drag-resizable.
const double kSidebarWidthDefault = 290.0;

/// App-wide appearance + language settings, persisted to drift (see `main`).
/// [AppSettings.chatWallpaper] values: the plain app background (also what
/// an empty value — the pre-pattern-default setting — means) and the doodle
/// pattern (the default); anything else is the path of an image.
const kChatWallpaperPlain = 'none';
const kChatWallpaperPattern = 'pattern';

@immutable
class AppSettings {
  const AppSettings({
    this.variant = AppThemeVariant.light,
    this.surface = SurfaceStyle.outline,
    this.density = AppDensity.comfortable,
    this.detailLayout = DetailLayout.twoPane,
    this.dateFormat = DateDisplayFormat.iso,
    this.companyTint = false,
    this.locale = const Locale('en'),
    this.translationLang = kDefaultTranslationLang,
    this.translationModel = '',
    this.fontFamily = kVietnamFont,
    this.componentRadius = kComponentRadiusDefault,
    this.accentColorValue,
    this.pinnedProjects = const <String>{},
    this.pinnedExecutions = const <PinnedExecution>[],
    this.sidebarWidth = kSidebarWidthDefault,
    this.chatAppearance = ChatAppearance.worknexus,
    this.chatPrimaryBubbles = false,
    this.chatWallpaper = kChatWallpaperPattern,
    this.chatWallpaperDim = 0.2,
    this.chatSendMarkdown = false,
    this.chatNotifications = true,
    this.chatCacheLimitMb = 2048,
    this.chatAutoDownloadVideos = true,
    this.chatAutoDownloadVideoMb = 20,
  });

  final AppThemeVariant variant;
  final SurfaceStyle surface;
  final AppDensity density;
  final DetailLayout detailLayout;

  /// How concrete timestamps render their date part across the app.
  final DateDisplayFormat dateFormat;

  final bool companyTint;
  final Locale locale;

  /// Target language a ticket is machine-translated *into* (the "Vietnamese" tab
  /// generalized). A BCP-47 code from [kTranslationLanguages]; defaults to
  /// [kDefaultTranslationLang]. Distinct from [locale], which is the app's UI
  /// language.
  final String translationLang;

  /// The `provider/model` OpenCode translates with (e.g. `opencode-go/glm-5.3`).
  /// Empty means "leave it to OpenCode's own default model", which is the
  /// behaviour before this setting existed.
  final String translationModel;

  /// Pinned ZenTao project keys (`"accountId:productId"`) surfaced at the top of
  /// the sources tree. Persisted so pins survive restarts.
  final Set<String> pinnedProjects;

  /// Pinned ZenTao executions surfaced alongside pinned projects in the tree's
  /// per-account "Pinned" area. Persisted so pins survive restarts.
  final List<PinnedExecution> pinnedExecutions;

  /// Width (logical px) of the left sidebar, adjustable by dragging its right
  /// edge. Persisted so the chosen width survives restarts.
  final double sidebarWidth;

  /// The user-chosen app primary/accent color (ARGB int), or `null` to use the
  /// active theme variant's built-in accent.
  final int? accentColorValue;

  /// The UI font family (a bundled or system family name). Monospace text
  /// (code / ids) always stays on [kMonoFont] regardless of this.
  final String fontFamily;

  /// User-chosen corner radius (logical px) for design-system components, driven
  /// by the settings slider. Clamped to [kComponentRadiusMin]..[kComponentRadiusMax].
  final double componentRadius;

  /// Message layout style of the chat view.
  final ChatAppearance chatAppearance;

  /// Send chat messages as Markdown (xxd `text`) instead of plain text.
  /// Own bubbles in Telegram/Zalo/Messenger/WeChat styles use the accent.
  final bool chatPrimaryBubbles;

  /// The chat background, shared by every chat style: '' or
  /// [kChatWallpaperPlain] = the plain app background, [kChatWallpaperPattern]
  /// = the doodle pattern, otherwise the path of a wallpaper image.
  final String chatWallpaper;

  /// How much a wallpaper image is darkened (0–1).
  final double chatWallpaperDim;
  final bool chatSendMarkdown;

  /// Show a desktop notification for new chat messages.
  final bool chatNotifications;

  /// Most disk space downloaded chat attachments may use, in MB.
  final int chatCacheLimitMb;

  /// Chat videos up to [chatAutoDownloadVideoMb] MB download on their own —
  /// for their preview frame and instant playback; larger ones (or all,
  /// when off) wait for a click.
  final bool chatAutoDownloadVideos;
  final int chatAutoDownloadVideoMb;

  AppSettings copyWith({
    AppThemeVariant? variant,
    SurfaceStyle? surface,
    AppDensity? density,
    DetailLayout? detailLayout,
    DateDisplayFormat? dateFormat,
    bool? companyTint,
    Locale? locale,
    String? translationLang,
    String? translationModel,
    String? fontFamily,
    double? componentRadius,
    Set<String>? pinnedProjects,
    List<PinnedExecution>? pinnedExecutions,
    double? sidebarWidth,
    ChatAppearance? chatAppearance,
    bool? chatPrimaryBubbles,
    String? chatWallpaper,
    double? chatWallpaperDim,
    bool? chatSendMarkdown,
    bool? chatNotifications,
    int? chatCacheLimitMb,
    bool? chatAutoDownloadVideos,
    int? chatAutoDownloadVideoMb,
    // Sentinel so `null` can be passed explicitly to reset to the theme accent.
    Object? accentColorValue = _unset,
  }) {
    return AppSettings(
      variant: variant ?? this.variant,
      surface: surface ?? this.surface,
      density: density ?? this.density,
      detailLayout: detailLayout ?? this.detailLayout,
      dateFormat: dateFormat ?? this.dateFormat,
      companyTint: companyTint ?? this.companyTint,
      locale: locale ?? this.locale,
      translationLang: translationLang ?? this.translationLang,
      translationModel: translationModel ?? this.translationModel,
      fontFamily: fontFamily ?? this.fontFamily,
      componentRadius: componentRadius ?? this.componentRadius,
      pinnedProjects: pinnedProjects ?? this.pinnedProjects,
      pinnedExecutions: pinnedExecutions ?? this.pinnedExecutions,
      sidebarWidth: sidebarWidth ?? this.sidebarWidth,
      chatAppearance: chatAppearance ?? this.chatAppearance,
      chatPrimaryBubbles: chatPrimaryBubbles ?? this.chatPrimaryBubbles,
      chatWallpaper: chatWallpaper ?? this.chatWallpaper,
      chatWallpaperDim: chatWallpaperDim ?? this.chatWallpaperDim,
      chatSendMarkdown: chatSendMarkdown ?? this.chatSendMarkdown,
      chatNotifications: chatNotifications ?? this.chatNotifications,
      chatCacheLimitMb: chatCacheLimitMb ?? this.chatCacheLimitMb,
      chatAutoDownloadVideos:
          chatAutoDownloadVideos ?? this.chatAutoDownloadVideos,
      chatAutoDownloadVideoMb:
          chatAutoDownloadVideoMb ?? this.chatAutoDownloadVideoMb,
      accentColorValue: identical(accentColorValue, _unset)
          ? this.accentColorValue
          : accentColorValue as int?,
    );
  }
}

/// Sentinel marking "argument not passed" in [AppSettings.copyWith], so a real
/// `null` can distinguish "reset to theme accent".
const Object _unset = Object();

/// The selectable UI fonts. Be Vietnam Pro / Geist Mono are served via
/// `google_fonts`; Space Grotesk / Space Mono are bundled in `assets/fonts/`;
/// the rest are standard macOS system families (rendered via the platform font
/// manager, with a fallback to the bundled sans if unavailable).
const List<String> kFontChoices = <String>[
  kSystemFont,
  kVietnamFont, // Be Vietnam Pro (default, via google_fonts)
  kSansFont, // Space Grotesk (bundled)
  'Helvetica Neue',
  'Avenir Next',
  'Georgia',
  kMonoFont, // Space Mono (bundled)
  kGeistMonoFont, // Geist Mono (via google_fonts)
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
  void setDateFormat(DateDisplayFormat f) =>
      _set(state.copyWith(dateFormat: f));
  void setCompanyTint(bool on) => _set(state.copyWith(companyTint: on));
  void setLocale(Locale l) => _set(state.copyWith(locale: l));
  void setTranslationLang(String code) =>
      _set(state.copyWith(translationLang: code));

  /// Pins the OpenCode model used for translation; empty restores OpenCode's
  /// own default.
  void setTranslationModel(String model) =>
      _set(state.copyWith(translationModel: model.trim()));
  void setFontFamily(String f) => _set(state.copyWith(fontFamily: f));
  void setChatAppearance(ChatAppearance a) =>
      _set(state.copyWith(chatAppearance: a));
  void setChatWallpaper(String wallpaper) =>
      _set(state.copyWith(chatWallpaper: wallpaper));
  void setChatWallpaperDim(double dim) =>
      _set(state.copyWith(chatWallpaperDim: dim.clamp(0, 0.8)));
  void setChatPrimaryBubbles(bool on) =>
      _set(state.copyWith(chatPrimaryBubbles: on));
  void setChatSendMarkdown(bool on) =>
      _set(state.copyWith(chatSendMarkdown: on));
  void setChatNotifications(bool on) =>
      _set(state.copyWith(chatNotifications: on));
  void setChatCacheLimitMb(int mb) =>
      _set(state.copyWith(chatCacheLimitMb: mb));
  void setChatAutoDownloadVideos(bool on) =>
      _set(state.copyWith(chatAutoDownloadVideos: on));
  void setChatAutoDownloadVideoMb(int mb) =>
      _set(state.copyWith(chatAutoDownloadVideoMb: mb));
  void setComponentRadius(double r) =>
      _set(state.copyWith(componentRadius: snapComponentRadius(r)));

  /// Sets the app primary color; pass `null` to fall back to the theme accent.
  void setAccentColor(int? value) =>
      _set(state.copyWith(accentColorValue: value));

  /// Sets the left sidebar width (logical px). Callers clamp to the allowed
  /// range before calling.
  void setSidebarWidth(double width) =>
      _set(state.copyWith(sidebarWidth: width));

  /// Pins/unpins a ZenTao project by its `"accountId:productId"` [key].
  void togglePinnedProject(String key) {
    final next = Set<String>.of(state.pinnedProjects);
    next.contains(key) ? next.remove(key) : next.add(key);
    _set(state.copyWith(pinnedProjects: next));
  }

  /// Pins/unpins a ZenTao [execution]. Matched by [PinnedExecution.key] so a
  /// second toggle removes it regardless of a since-changed display name.
  void togglePinnedExecution(PinnedExecution execution) {
    final next = List<PinnedExecution>.of(state.pinnedExecutions);
    final index = next.indexWhere((e) => e.key == execution.key);
    index >= 0 ? next.removeAt(index) : next.add(execution);
    _set(state.copyWith(pinnedExecutions: next));
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
