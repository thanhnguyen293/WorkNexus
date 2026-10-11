import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/database/database.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/chat/data/datasources/link_preview_http_datasource.dart';
import 'package:work_nexus/features/chat/data/datasources/link_preview_local_datasource.dart';
import 'package:work_nexus/features/chat/data/repositories/cached_link_preview_repository.dart';
import 'package:work_nexus/features/chat/domain/entities/link_preview.dart';

class _Http extends Mock implements LinkPreviewHttpDatasource {}

const _url = 'https://example.com/a';
const _preview = LinkPreview(
  url: 'https://example.com/landed',
  title: 'Title',
  imageUrl: 'https://example.com/a.png',
);

void main() {
  late AppDatabase db;
  late _Http http;
  late DateTime now;

  CachedLinkPreviewRepository repo() => CachedLinkPreviewRepository(
    local: LinkPreviewLocalDatasource(db),
    http: http,
    now: () => now,
  );

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    http = _Http();
    now = DateTime(2026, 10, 2);
  });
  tearDown(() => db.close());

  test('a fetched preview is stored and served after a restart', () async {
    when(() => http.fetch(_url)).thenAnswer((_) async => const Ok(_preview));

    expect((await repo().preview(_url)).valueOrNull, _preview);
    // A new repository (fresh memory) reads it back without the web.
    expect((await repo().preview(_url)).valueOrNull, _preview);
    verify(() => http.fetch(_url)).called(1);
  });

  test('"nothing to show" is stored too', () async {
    when(() => http.fetch(_url)).thenAnswer((_) async => const Ok(null));

    await repo().preview(_url);
    final again = await repo().preview(_url);

    expect(again, isA<Ok<LinkPreview?>>());
    expect(again.valueOrNull, isNull);
    verify(() => http.fetch(_url)).called(1);
  });

  test('a failure is not kept: the next look retries', () async {
    final r = repo();
    when(
      () => http.fetch(_url),
    ).thenAnswer((_) async => const Err(NetworkFailure('down')));
    expect(await r.preview(_url), isA<Err<LinkPreview?>>());

    when(() => http.fetch(_url)).thenAnswer((_) async => const Ok(_preview));
    expect((await r.preview(_url)).valueOrNull, _preview);
    expect((await repo().preview(_url)).valueOrNull, _preview);
    verify(() => http.fetch(_url)).called(2);
  });

  test('a stale preview is refetched, and kept when that fails', () async {
    when(() => http.fetch(_url)).thenAnswer((_) async => const Ok(_preview));
    await repo().preview(_url);

    now = now.add(CachedLinkPreviewRepository.maxAge);
    when(
      () => http.fetch(_url),
    ).thenAnswer((_) async => const Err(NetworkFailure('down')));

    expect((await repo().preview(_url)).valueOrNull, _preview);
    verify(() => http.fetch(_url)).called(2);
  });
}
