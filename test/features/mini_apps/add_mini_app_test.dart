import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/mini_apps/domain/entities/mini_app.dart';
import 'package:work_nexus/features/mini_apps/domain/repositories/mini_app_repository.dart';
import 'package:work_nexus/features/mini_apps/domain/usecases/add_mini_app.dart';
import 'package:work_nexus/features/mini_apps/domain/usecases/normalize_mini_app_url.dart';

class _MockRepo extends Mock implements MiniAppRepository {}

void main() {
  group('NormalizeMiniAppUrl', () {
    const normalize = NormalizeMiniAppUrl();

    test('adds https to a bare host', () {
      expect(normalize('example.com/a')?.toString(), 'https://example.com/a');
    });

    test('keeps http and https addresses', () {
      expect(normalize(' http://x.dev ')?.scheme, 'http');
      expect(normalize('https://x.dev')?.scheme, 'https');
    });

    test('treats localhost:port as a host, not a scheme', () {
      expect(normalize('localhost:3000')?.toString(), 'https://localhost:3000');
    });

    test('rejects other schemes, blanks and spaces', () {
      expect(normalize('file:///C:/a.html'), isNull);
      expect(normalize('javascript:alert(1)'), isNull);
      expect(normalize('   '), isNull);
      expect(normalize('not a url'), isNull);
    });
  });

  group('AddMiniApp', () {
    late _MockRepo repo;
    setUp(() {
      repo = _MockRepo();
      registerFallbackValue(
        const MiniApp(id: 'x', name: 'x', url: 'https://x', position: 0),
      );
      when(() => repo.save(any())).thenAnswer((_) async => const Ok(null));
      when(
        () => repo.fetchSiteIcon(
          id: any(named: 'id'),
          pageUrl: any(named: 'pageUrl'),
        ),
      ).thenAnswer((_) async => const Ok(null));
    });

    test('names it after the host and puts it last', () async {
      final res = await AddMiniApp(repo)(
        url: 'www.example.com',
        existing: const [
          MiniApp(id: 'a', name: 'A', url: 'https://a.io', position: 4),
        ],
      );
      final app = res.valueOrNull!;
      expect(app.name, 'example.com');
      expect(app.position, 5);
      verify(() => repo.save(app)).called(1);
    });

    test('fails on a bad address without saving', () async {
      final res = await AddMiniApp(repo)(url: 'ftp://x', existing: const []);
      expect(res.failureOrNull, isA<ParseFailure>());
      verifyNever(() => repo.save(any()));
    });
  });
}
