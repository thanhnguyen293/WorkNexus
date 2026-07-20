/// The languages a ticket can be machine-translated into. Pure data shared by
/// the data layer (the OpenCode prompt uses [englishName]) and presentation (the
/// picker + tab use [flag] and [nativeName]), so it lives in the shared kernel.
///
/// To offer another target language, add one entry here — nothing else in the
/// translation flow is language-specific.
class TranslationLanguage {
  const TranslationLanguage({
    required this.code,
    required this.englishName,
    required this.nativeName,
    required this.flag,
  });

  /// BCP-47 primary subtag persisted with the translation + settings (`vi`).
  final String code;

  /// English name fed to the model prompt (`Vietnamese`).
  final String englishName;

  /// Endonym shown in the UI (`Tiếng Việt`).
  final String nativeName;

  /// Flag emoji shown in the picker and the translation tab.
  final String flag;
}

/// Default target language — Vietnamese, per the app's ZenTao-first audience.
const String kDefaultTranslationLang = 'vi';

/// The selectable translation targets (default [kDefaultTranslationLang] first).
const List<TranslationLanguage> kTranslationLanguages = <TranslationLanguage>[
  TranslationLanguage(
    code: 'vi',
    englishName: 'Vietnamese',
    nativeName: 'Tiếng Việt',
    flag: '🇻🇳',
  ),
  TranslationLanguage(
    code: 'en',
    englishName: 'English',
    nativeName: 'English',
    flag: '🇬🇧',
  ),
  TranslationLanguage(
    code: 'ja',
    englishName: 'Japanese',
    nativeName: '日本語',
    flag: '🇯🇵',
  ),
  TranslationLanguage(
    code: 'zh',
    englishName: 'Chinese (Simplified)',
    nativeName: '中文',
    flag: '🇨🇳',
  ),
  TranslationLanguage(
    code: 'ko',
    englishName: 'Korean',
    nativeName: '한국어',
    flag: '🇰🇷',
  ),
];

/// Resolves a language [code] to its descriptor, falling back to the default
/// (first entry) for an unknown/legacy code.
TranslationLanguage translationLanguageFor(String code) =>
    kTranslationLanguages.firstWhere(
      (l) => l.code == code,
      orElse: () => kTranslationLanguages.first,
    );
