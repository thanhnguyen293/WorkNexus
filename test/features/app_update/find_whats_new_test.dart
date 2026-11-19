import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/app_update/domain/repositories/seen_version_store.dart';
import 'package:work_nexus/features/app_update/domain/usecases/collect_release_notes.dart';
import 'package:work_nexus/features/app_update/domain/usecases/find_whats_new.dart';

import 'support/update_test_app.dart';

class _MockSeen extends Mock implements SeenVersionStore {}

void main() {
  late MockUpdateRepository releases;
  late _MockSeen seen;

  setUp(() {
    releases = mockUpdateRepository();
    seen = _MockSeen();
    when(() => releases.currentVersion()).thenAnswer((_) async => '1.3.0');
    when(() => seen.setLastSeen(any())).thenAnswer((_) async => const Ok(null));
    when(releases.fetchStableReleaseNotes).thenAnswer(
      (_) async => const Ok([
        (version: 'v1.0.0', notes: '- One'),
        (version: 'v1.1.0', notes: '- Two'),
        (version: 'v1.2.0', notes: ''),
        (version: 'v1.3.0', notes: '- Four'),
        (version: 'v1.4.0-beta.1', notes: '- Beta'),
      ]),
    );
  });

  test('after an update, lists every release since the last one run', () async {
    when(seen.lastSeen).thenAnswer((_) async => const Ok('1.0.0'));

    final news = (await FindWhatsNew(releases, seen)()).valueOrNull;

    expect(news?.from, '1.0.0');
    expect(news?.to, '1.3.0');
    expect(news?.notes, '## v1.3.0\n\n- Four\n\n## v1.1.0\n\n- Two');
    verify(() => seen.setLastSeen('1.3.0')).called(1);
  });

  test('says nothing on the first launch, but remembers the version', () async {
    when(seen.lastSeen).thenAnswer((_) async => const Ok(null));

    expect((await FindWhatsNew(releases, seen)()).valueOrNull, isNull);
    verify(() => seen.setLastSeen('1.3.0')).called(1);
  });

  test('says nothing when the version has not changed', () async {
    when(seen.lastSeen).thenAnswer((_) async => const Ok('1.3.0'));

    expect((await FindWhatsNew(releases, seen)()).valueOrNull, isNull);
    verifyNever(() => seen.setLastSeen(any()));
  });

  test('tries again next launch when the notes cannot be read', () async {
    when(seen.lastSeen).thenAnswer((_) async => const Ok('1.0.0'));
    when(
      releases.fetchStableReleaseNotes,
    ).thenAnswer((_) async => const Err(NetworkFailure('offline')));

    expect((await FindWhatsNew(releases, seen)()).isErr, isTrue);
    verifyNever(() => seen.setLastSeen(any()));
  });

  test('combine ignores pre-releases and versions outside the range', () {
    final text = CollectReleaseNotes.combine(
      const [
        (version: 'v2.0.0', notes: '- Too new'),
        (version: 'v1.5.0-rc.1', notes: '- RC'),
        (version: '1.5.0', notes: '- Five'),
      ],
      after: '1.4.0',
      upTo: 'v1.5.0',
    );
    expect(text, '## v1.5.0\n\n- Five');
  });
}
