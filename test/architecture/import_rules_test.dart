import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('Architecture: Import Rules and Layering Enforcement', () {
    late final Directory libDir;
    late final Set<String> allowlistedEdges;
    late final Map<String, int> uiLineExemptions;
    late final Map<String, int> nonUiLineExemptions;

    setUpAll(() {
      libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue, reason: 'lib directory must exist');

      final allowlistFile = File(
        'test/architecture/import_rules_allowlist.yaml',
      );
      expect(
        allowlistFile.existsSync(),
        isTrue,
        reason: 'Allowlist YAML must exist',
      );

      final doc = loadYaml(allowlistFile.readAsStringSync()) as YamlMap;

      // Parse import edges
      allowlistedEdges = <String>{};
      final edges = doc['import_edges'] as YamlList?;
      if (edges != null) {
        for (final rawEdge in edges) {
          final edge = rawEdge as YamlMap;
          final source = (edge['source'] as String).replaceAll('\\', '/');
          final target = (edge['target'] as String).replaceAll('\\', '/');
          allowlistedEdges.add('$source -> $target');
        }
      }

      // Parse line count exemptions
      uiLineExemptions = <String, int>{};
      nonUiLineExemptions = <String, int>{};
      final lineExemptions = doc['line_count_exemptions'] as YamlList?;
      if (lineExemptions != null) {
        for (final rawItem in lineExemptions) {
          final item = rawItem as YamlMap;
          final file = (item['file'] as String).replaceAll('\\', '/');
          final maxLines = item['max_lines'] as int;
          uiLineExemptions[file] = maxLines;
          nonUiLineExemptions[file] = maxLines;
        }
      }
    });

    test('lib/ files obey layer and feature boundary rules', () {
      final importRegex = RegExp(
        r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
      );
      final violations = <String>[];

      // Find all hand-written Dart files in lib/
      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) {
            final p = f.path.replaceAll('\\', '/');
            return p.endsWith('.dart') &&
                !p.endsWith('.g.dart') &&
                !p.endsWith('.freezed.dart') &&
                !p.endsWith('.config.dart') &&
                !p.contains('/l10n/') &&
                !p.contains('/gen/');
          })
          .toList();

      for (final file in dartFiles) {
        final filePath = file.path.replaceAll('\\', '/');
        final lines = file.readAsLinesSync();

        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          final match = importRegex.firstMatch(line);
          if (match == null) continue;

          final uri = match.group(1)!;
          final lineNo = i + 1;

          // 1. Pure domain rules: domain must not import flutter, drift, dio, riverpod
          if (filePath.contains('/domain/')) {
            const forbiddenDomainPackages = [
              'package:flutter/',
              'package:drift/',
              'package:dio/',
              'package:flutter_riverpod/',
              'package:riverpod/',
            ];
            for (final forbidden in forbiddenDomainPackages) {
              if (uri.startsWith(forbidden)) {
                final edgeKey = '$filePath -> $uri';
                if (!allowlistedEdges.contains(edgeKey)) {
                  violations.add(
                    '[Pure Domain Violation] $filePath:$lineNo imports $uri (domain must remain pure Dart)',
                  );
                }
              }
            }
          }

          // Resolve internal package/relative imports
          String? targetPath;
          if (uri.startsWith('package:work_nexus/')) {
            targetPath = 'lib/${uri.substring('package:work_nexus/'.length)}';
          } else if (uri.startsWith('./') || uri.startsWith('../')) {
            targetPath = _normalizePath('${file.parent.path}/$uri');
          }

          if (targetPath == null) continue;
          targetPath = targetPath.replaceAll('\\', '/');
          final edgeKey = '$filePath -> $targetPath';

          if (allowlistedEdges.contains(edgeKey)) {
            continue;
          }

          // 2. Domain must not import data/ or presentation/
          if (filePath.contains('/domain/') &&
              (targetPath.contains('/data/') ||
                  targetPath.contains('/presentation/'))) {
            violations.add(
              '[Layering: Domain -> Data/Presentation] $filePath:$lineNo -> $targetPath',
            );
          }

          // 3. Presentation must not import data/ (Rule 1.3)
          if (filePath.contains('/presentation/') &&
              targetPath.contains('/data/')) {
            violations.add(
              '[Rule 1.3: Presentation -> Data] $filePath:$lineNo -> $targetPath',
            );
          }

          // 4. Feature boundary rules: features/a must not import features/b
          if (filePath.startsWith('lib/features/') &&
              targetPath.startsWith('lib/features/')) {
            final sourceFeature = filePath.split('/')[2];
            final targetFeature = targetPath.split('/')[2];
            if (sourceFeature != targetFeature) {
              violations.add(
                '[Rule 10.1: Feature Boundary] $filePath:$lineNo -> $targetPath ($sourceFeature -> $targetFeature)',
              );
            }
          }

          // 5. Tool modules boundary rules: tools/a must not import tools/b, tools <-> features
          if (filePath.startsWith('lib/tools/')) {
            final sourceTool = filePath.split('/')[2];
            if (targetPath.startsWith('lib/tools/')) {
              final targetTool = targetPath.split('/')[2];
              if (sourceTool != targetTool) {
                violations.add(
                  '[Tool Isolation] $filePath:$lineNo -> $targetPath ($sourceTool -> $targetTool)',
                );
              }
            } else if (targetPath.startsWith('lib/features/')) {
              violations.add(
                '[Tool Isolation: Tool -> Feature] $filePath:$lineNo -> $targetPath',
              );
            } else if (targetPath.startsWith('lib/app/')) {
              violations.add(
                '[Tool Isolation: Tool -> App] $filePath:$lineNo -> $targetPath',
              );
            }
          }

          if (filePath.startsWith('lib/features/') &&
              targetPath.startsWith('lib/tools/')) {
            violations.add(
              '[Tool Isolation: Feature -> Tool] $filePath:$lineNo -> $targetPath',
            );
          }

          // 6. Shared must not import tools/, features/ or app/
          if (filePath.startsWith('lib/shared/')) {
            if (targetPath.startsWith('lib/tools/') ||
                targetPath.startsWith('lib/features/') ||
                targetPath.startsWith('lib/app/')) {
              violations.add(
                '[Shared Inward Rule] $filePath:$lineNo -> $targetPath (shared must only import core or shared)',
              );
            }
          }

          // 7. Core must not import tools/, features/, shared/ or app/
          if (filePath.startsWith('lib/core/')) {
            if (targetPath.startsWith('lib/tools/') ||
                targetPath.startsWith('lib/features/') ||
                targetPath.startsWith('lib/shared/') ||
                targetPath.startsWith('lib/app/')) {
              violations.add(
                '[Core Layering Rule] $filePath:$lineNo -> $targetPath (core must not import higher layers)',
              );
            }
          }
        }
      }

      if (violations.isNotEmpty) {
        fail(
          'Found ${violations.length} forbidden architecture imports:\n'
          '${violations.join('\n')}\n\n'
          'To fix: resolve the forbidden dependency or document temporary exceptions in test/architecture/import_rules_allowlist.yaml',
        );
      }
    });

    test(
      'Hand-written file line counts obey limits (UI <= 300 lines, non-UI <= 400 lines)',
      () {
        final uiViolations = <String>[];
        final nonUiWarnings = <String>[];

        final dartFiles = libDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) {
              final p = f.path.replaceAll('\\', '/');
              return p.endsWith('.dart') &&
                  !p.endsWith('.g.dart') &&
                  !p.endsWith('.freezed.dart') &&
                  !p.contains('/l10n/') &&
                  !p.contains('/gen/');
            })
            .toList();

        for (final file in dartFiles) {
          final filePath = file.path.replaceAll('\\', '/');
          final lineCount = file.readAsLinesSync().length;
          final isUi =
              filePath.contains('/presentation/') ||
              filePath.contains('/widgets/') ||
              filePath.contains('/pages/') ||
              filePath.contains('/shell/');

          if (isUi) {
            final maxAllowed = uiLineExemptions[filePath] ?? 300;
            if (lineCount > maxAllowed) {
              uiViolations.add(
                '$filePath: $lineCount lines (limit $maxAllowed)',
              );
            }
          } else {
            final maxAllowed = nonUiLineExemptions[filePath] ?? 400;
            if (lineCount > maxAllowed) {
              nonUiWarnings.add(
                '$filePath: $lineCount lines (limit $maxAllowed)',
              );
            }
          }
        }

        if (uiViolations.isNotEmpty) {
          fail(
            'Found ${uiViolations.length} UI files exceeding line limits (Rule 6.1: max 300 lines):\n'
            '${uiViolations.join('\n')}',
          );
        }

        // Non-UI warnings can be tracked via allowlist or CI logs if needed
        expect(
          nonUiWarnings,
          isEmpty,
          reason:
              'Non-UI files over 400 lines should be documented in allowlist',
        );
      },
    );
  });
}

String _normalizePath(String rawPath) {
  final parts = rawPath.replaceAll('\\', '/').split('/');
  final resolved = <String>[];
  for (final part in parts) {
    if (part.isEmpty || part == '.') continue;
    if (part == '..') {
      if (resolved.isNotEmpty) resolved.removeLast();
    } else {
      resolved.add(part);
    }
  }
  return resolved.join('/');
}
