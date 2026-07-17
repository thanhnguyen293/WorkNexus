import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/translation_record.dart';
import 'package:work_nexus/core/domain/value_objects/translation_state.dart';
import 'package:work_nexus/features/translation/domain/usecases/resolve_translation_state.dart';

TranslationRecord _rec(String hash) => TranslationRecord(
  ticketId: 't',
  sourceHash: hash,
  targetLang: 'vi',
  translatedTitle: 'Tiêu đề',
  translatedBody: 'Nội dung',
  model: 'm',
  templateVersion: 'v1',
  createdAt: DateTime(2026, 7, 17),
);

void main() {
  const resolve = ResolveTranslationState();

  test('none when no record and no error', () {
    expect(resolve(currentSourceHash: 'h1'), TranslationState.none);
  });

  test('error when no record but last attempt failed', () {
    expect(
      resolve(currentSourceHash: 'h1', hasError: true),
      TranslationState.error,
    );
  });

  test('loading takes precedence', () {
    expect(
      resolve(currentSourceHash: 'h1', record: _rec('h1'), loading: true),
      TranslationState.loading,
    );
  });

  test('done when cached hash matches current', () {
    expect(
      resolve(currentSourceHash: 'h1', record: _rec('h1')),
      TranslationState.done,
    );
  });

  test('outdated when source changed since translation', () {
    expect(
      resolve(currentSourceHash: 'h2', record: _rec('h1')),
      TranslationState.outdated,
    );
  });

  test(
    'stale record with error still shows outdated (keeps prior translation)',
    () {
      expect(
        resolve(currentSourceHash: 'h2', record: _rec('h1'), hasError: true),
        TranslationState.outdated,
      );
    },
  );
}
