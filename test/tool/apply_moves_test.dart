import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import '../../tool/apply_moves.dart';

void main() {
  group('MoveApplier', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('apply_moves_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('parses markdown manifest table correctly', () {
      const manifest = '''
# Sample Manifest
| Source | Destination | Phase | Notes |
|---|---|---|---|
| `lib/features/board/foo.dart` | `lib/tools/zentao/foo.dart` | Phase 4 | Model |
| `lib/features/board/bar.dart` | `lib/tools/github/bar.dart` | Phase 4 | View |
| `lib/legacy/old.dart` | `lib/app/new.dart` | Phase 2 | Root |
''';

      final phase4Moves = MoveApplier.parseManifest(
        manifest,
        targetPhase: 'Phase 4',
      );
      expect(phase4Moves, {
        'lib/features/board/foo.dart': 'lib/tools/zentao/foo.dart',
        'lib/features/board/bar.dart': 'lib/tools/github/bar.dart',
      });

      final phase2Moves = MoveApplier.parseManifest(
        manifest,
        targetPhase: 'Phase 2',
      );
      expect(phase2Moves, {'lib/legacy/old.dart': 'lib/app/new.dart'});
    });

    test('moves files and rewrites relative and package imports in fixture tree', () {
      // Setup fixture tree:
      // tempDir/
      //   lib/
      //     a/
      //       source_a.dart -> imports ../b/target_b.dart, package:work_nexus/b/target_b.dart
      //     b/
      //       target_b.dart
      //     c/
      //       caller_c.dart -> imports ../b/target_b.dart

      final dirA = Directory('${tempDir.path}/lib/a')
        ..createSync(recursive: true);
      final dirB = Directory('${tempDir.path}/lib/b')
        ..createSync(recursive: true);
      final dirC = Directory('${tempDir.path}/lib/c')
        ..createSync(recursive: true);

      final fileB = File('${dirB.path}/target_b.dart')
        ..writeAsStringSync('class TargetB {}\n');

      final fileA = File('${dirA.path}/source_a.dart')
        ..writeAsStringSync('''
import '../b/target_b.dart';
import 'package:work_nexus/b/target_b.dart';

class SourceA {
  final TargetB b;
  SourceA(this.b);
}
''');

      File('${dirC.path}/caller_c.dart').writeAsStringSync('''
import '../b/target_b.dart';

class CallerC {
  final TargetB b;
  CallerC(this.b);
}
''');

      // Move target_b.dart from lib/b/target_b.dart -> lib/tools/target_b.dart
      // Move source_a.dart from lib/a/source_a.dart -> lib/shared/source_a.dart
      final moves = {
        'lib/b/target_b.dart': 'lib/tools/target_b.dart',
        'lib/a/source_a.dart': 'lib/shared/source_a.dart',
      };

      final applier = MoveApplier(
        moves: moves,
        repoRoot: tempDir.path,
        dryRun: false,
      );

      final logs = applier.run();
      expect(logs.any((l) => l.contains('Rewritten')), isTrue);

      // Verify old files no longer exist and new files exist
      expect(fileB.existsSync(), isFalse);
      expect(fileA.existsSync(), isFalse);
      expect(
        File('${tempDir.path}/lib/tools/target_b.dart').existsSync(),
        isTrue,
      );
      expect(
        File('${tempDir.path}/lib/shared/source_a.dart').existsSync(),
        isTrue,
      );

      // Verify caller_c.dart relative import was rewritten from ../b/target_b.dart to ../tools/target_b.dart
      final updatedC = File('${dirC.path}/caller_c.dart').readAsStringSync();
      expect(updatedC, contains("import '../tools/target_b.dart';"));

      // Verify moved source_a.dart relative import was rewritten to point to new target location
      final updatedA = File(
        '${tempDir.path}/lib/shared/source_a.dart',
      ).readAsStringSync();
      expect(updatedA, contains("import '../tools/target_b.dart';"));
      expect(
        updatedA,
        contains("import 'package:work_nexus/tools/target_b.dart';"),
      );
    });
  });
}
