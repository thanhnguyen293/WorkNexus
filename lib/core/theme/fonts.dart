/// Sans + mono font families (bundled offline in `assets/fonts/`).
const String kSystemFont = '__system__';
const String kSansFont = 'Space Grotesk';
const String kMonoFont = 'Space Mono';

/// The default UI font — Be Vietnam Pro, loaded via `google_fonts` (good Latin +
/// Vietnamese coverage). This is a marker family name resolved to the actual
/// google-fonts family in `buildAppTheme`; it is not a bundled asset.
const String kVietnamFont = 'Be Vietnam Pro';

/// Geist Mono — a monospace UI font also served via `google_fonts` (not a
/// bundled asset). Like [kVietnamFont], it is a marker family name resolved to
/// the generated google-fonts family in `buildAppTheme`.
const String kGeistMonoFont = 'Geist Mono';
