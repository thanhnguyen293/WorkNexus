import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/util/translation_languages.dart';

void main() {
  group('translation languages', () {
    test('the default is Vietnamese and is listed first', () {
      expect(kDefaultTranslationLang, 'vi');
      expect(kTranslationLanguages.first.code, 'vi');
      expect(kTranslationLanguages.first.flag, '🇻🇳');
    });

    test('every language carries a code, names and a flag', () {
      for (final lang in kTranslationLanguages) {
        expect(lang.code, isNotEmpty);
        expect(lang.englishName, isNotEmpty);
        expect(lang.nativeName, isNotEmpty);
        expect(lang.flag, isNotEmpty);
      }
    });

    test('codes are unique', () {
      final codes = kTranslationLanguages.map((l) => l.code).toList();
      expect(codes.toSet().length, codes.length);
    });

    test('lookup resolves a known code to its descriptor', () {
      final ja = translationLanguageFor('ja');
      expect(ja.code, 'ja');
      expect(ja.englishName, 'Japanese');
    });

    test('lookup falls back to the default for an unknown/legacy code', () {
      expect(translationLanguageFor('xx').code, kDefaultTranslationLang);
      expect(translationLanguageFor('').code, kDefaultTranslationLang);
    });
  });
}
