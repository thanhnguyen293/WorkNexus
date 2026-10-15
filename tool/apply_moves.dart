import 'dart:io';

/// Rewrites import, export, part, and part of directives based on a move mapping.
class MoveApplier {
  MoveApplier({
    required this.moves,
    this.repoRoot = '.',
    this.dryRun = true,
  });

  /// Map of oldPath -> newPath (relative to repo root, e.g. lib/foo/bar.dart -> lib/baz/bar.dart)
  final Map<String, String> moves;
  final String repoRoot;
  final bool dryRun;

  static final RegExp directiveRegex = RegExp(
    r'''^(\s*(?:import|export|part(?:\s+of)?)\s+['"])([^'"]+)(['"].*)$''',
  );

  /// Parse move manifest markdown file
  static Map<String, String> parseManifest(String manifestContent, {String? targetPhase}) {
    final moves = <String, String>{};
    final lines = manifestContent.split('\n');
    
    for (final line in lines) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('|') || !trimmed.endsWith('|')) continue;
      final parts = trimmed
          .split('|')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      if (parts.length < 3) continue;
      // Skip header and separator
      if (parts[0] == 'Source' || parts[0].startsWith('---')) continue;

      final source = parts[0].replaceAll('`', '').trim();
      final dest = parts[1].replaceAll('`', '').trim();
      final phase = parts[2].trim();

      if (targetPhase != null && !phase.toLowerCase().contains(targetPhase.toLowerCase())) {
        continue;
      }

      if (source.isNotEmpty && dest.isNotEmpty && source != dest) {
        moves[source] = dest;
      }
    }

    return moves;
  }

  /// Expands moves with sibling generated files (.g.dart, .freezed.dart)
  static Map<String, String> expandWithGeneratedSiblings(
    Map<String, String> moves, {
    String repoRoot = '.',
  }) {
    final expanded = Map<String, String>.from(moves);
    for (final entry in moves.entries) {
      final from = entry.key;
      final to = entry.value;
      if (from.endsWith('.dart') &&
          !from.endsWith('.g.dart') &&
          !from.endsWith('.freezed.dart')) {
        final base = from.substring(0, from.length - '.dart'.length);
        final destBase = to.substring(0, to.length - '.dart'.length);
        for (final ext in ['.freezed.dart', '.g.dart']) {
          final genFrom = '$base$ext';
          if (File(repoRoot == '.' ? genFrom : '$repoRoot/$genFrom').existsSync()) {
            expanded[genFrom] = '$destBase$ext';
          }
        }
      }
    }
    return expanded;
  }

  /// Execute or preview the moves
  List<String> run() {
    final logs = <String>[];
    logs.add('=== MoveApplier (${dryRun ? "DRY RUN" : "EXECUTE"}) ===');
    logs.add('Applying ${moves.length} moves...');

    // 1. Plan or execute git mv
    for (final entry in moves.entries) {
      final from = entry.key;
      final to = entry.value;
      logs.add('MOVE: $from -> $to');

      if (!dryRun) {
        final toDir = Directory(_p(File(to).parent.path));
        if (!toDir.existsSync()) {
          toDir.createSync(recursive: true);
        }
        final result = Process.runSync('git', ['mv', from, to], workingDirectory: repoRoot);
        if (result.exitCode != 0) {
          // Fallback to File.rename if git mv fails (e.g. untracked fixture)
          final fromFile = File(_p(from));
          if (fromFile.existsSync()) {
            fromFile.renameSync(_p(to));
          } else {
            logs.add('  WARNING: $from does not exist');
          }
        }
      }
    }

    // 2. Find all Dart files to rewrite directives
    final dartFiles = Directory(repoRoot)
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) {
          final p = f.path.replaceAll('\\', '/');
          return p.endsWith('.dart') &&
              !p.contains('/.dart_tool/') &&
              !p.contains('/build/');
        })
        .toList();

    var rewrittenFilesCount = 0;

    for (final file in dartFiles) {
      final currentRelPath = _normalizePath(
        file.path.replaceAll('\\', '/').substring(
          repoRoot == '.' ? 0 : repoRoot.length + 1,
        ),
      );

      // Determine new relative path of this file (if it was moved)
      final newRelPath = moves[currentRelPath] ?? currentRelPath;

      final content = file.readAsStringSync();
      final lines = content.split('\n');
      var fileChanged = false;
      final newLines = <String>[];

      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final match = directiveRegex.firstMatch(line);
        if (match == null) {
          newLines.add(line);
          continue;
        }

        final prefix = match.group(1)!;
        final uri = match.group(2)!;
        final suffix = match.group(3)!;

        final newUri = _rewriteUri(
          uri: uri,
          currentOldFile: currentRelPath,
          currentNewFile: newRelPath,
        );

        if (newUri != uri) {
          fileChanged = true;
          logs.add('  REWRITE in $currentRelPath:${i + 1}: $uri -> $newUri');
          newLines.add('$prefix$newUri$suffix');
        } else {
          newLines.add(line);
        }
      }

      if (fileChanged) {
        rewrittenFilesCount++;
        if (!dryRun) {
          // If the file was moved, write to its new location
          final targetPath = _p(newRelPath);
          File(targetPath).writeAsStringSync(newLines.join('\n'));
        }
      }
    }

    logs.add('Rewritten $rewrittenFilesCount files.');
    return logs;
  }

  String _rewriteUri({
    required String uri,
    required String currentOldFile,
    required String currentNewFile,
  }) {
    // Case 1: package:work_nexus/ import
    if (uri.startsWith('package:work_nexus/')) {
      final oldTarget = 'lib/${uri.substring('package:work_nexus/'.length)}';
      final newTarget = moves[oldTarget];
      if (newTarget != null && newTarget.startsWith('lib/')) {
        return 'package:work_nexus/${newTarget.substring(4)}';
      }
      return uri;
    }

    // Case 2: relative import/export/part
    if (uri.startsWith('./') || uri.startsWith('../') || (!uri.contains(':') && !uri.startsWith('/'))) {
      // Resolve what the old target was
      final oldDir = File(currentOldFile).parent.path.replaceAll('\\', '/');
      final rawTarget = _normalizePath('$oldDir/$uri');
      
      // Check if the target was moved
      final newTarget = moves[rawTarget] ?? rawTarget;

      // If either the current file moved OR the target moved, recompute relative path
      if (moves.containsKey(currentOldFile) || moves.containsKey(rawTarget)) {
        final newDir = File(currentNewFile).parent.path.replaceAll('\\', '/');
        return _computeRelativePath(fromDir: newDir, toFile: newTarget);
      }
    }

    return uri;
  }

  String _p(String relativePath) {
    if (repoRoot == '.') return relativePath;
    return '$repoRoot/$relativePath';
  }

  static String _normalizePath(String rawPath) {
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

  static String _computeRelativePath({required String fromDir, required String toFile}) {
    final fromParts = fromDir.split('/').where((s) => s.isNotEmpty && s != '.').toList();
    final toParts = toFile.split('/').where((s) => s.isNotEmpty && s != '.').toList();

    var commonPrefixLength = 0;
    while (commonPrefixLength < fromParts.length &&
        commonPrefixLength < toParts.length &&
        fromParts[commonPrefixLength] == toParts[commonPrefixLength]) {
      commonPrefixLength++;
    }

    final upCount = fromParts.length - commonPrefixLength;
    final downParts = toParts.sublist(commonPrefixLength);

    if (upCount == 0) {
      return downParts.join('/');
    }

    final resultParts = List<String>.filled(upCount, '..', growable: true)
      ..addAll(downParts);
    return resultParts.join('/');
  }
}

void main(List<String> args) {
  var manifestPath = 'docs/openspecs/restructure-tool-modules/move-manifest.md';
  String? targetPhase;
  var dryRun = true;

  for (final arg in args) {
    if (arg.startsWith('--manifest=')) {
      manifestPath = arg.substring('--manifest='.length);
    } else if (arg.startsWith('--phase=')) {
      targetPhase = arg.substring('--phase='.length);
    } else if (arg == '--execute') {
      dryRun = false;
    } else if (arg == '--dry-run') {
      dryRun = true;
    }
  }

  final manifestFile = File(manifestPath);
  if (!manifestFile.existsSync()) {
    stderr.writeln('Manifest file not found: $manifestPath');
    exit(1);
  }

  final rawMoves = MoveApplier.parseManifest(manifestFile.readAsStringSync(), targetPhase: targetPhase);
  final moves = MoveApplier.expandWithGeneratedSiblings(rawMoves);
  final applier = MoveApplier(moves: moves, dryRun: dryRun);
  final logs = applier.run();
  for (final log in logs) {
    stdout.writeln(log);
  }
}
