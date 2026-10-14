import 'dart:io';

/// Resolves CLI binaries (GUI apps on macOS don't inherit the shell PATH) and
/// spawns them.
class CliRunner {
  const CliRunner();

  /// Whether spawned CLIs must go through a shell. On Windows the binary may be
  /// a `.cmd`/`.bat` shim (e.g. npm-installed `opencode`), which `CreateProcess`
  /// cannot launch directly — it needs `%COMSPEC% /c`.
  static bool get needsShell => Platform.isWindows;

  Future<String?> resolve(String name, {String? override}) async {
    if (override != null && override.trim().isNotEmpty) return override.trim();
    return Platform.isWindows ? _resolveWindows(name) : _resolveUnix(name);
  }

  /// macOS/Linux: a GUI launch omits the interactive-shell PATH (nvm, asdf,
  /// Homebrew, `~/.local/bin`, …), so ask a login shell, then fall back to a
  /// direct PATH scan for non-interactive shells.
  Future<String?> _resolveUnix(String name) async {
    final shell = Platform.environment['SHELL'] ?? '/bin/zsh';
    try {
      final res = await Process.run(shell, ['-lic', 'command -v $name']);
      final hit = res.stdout
          .toString()
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.startsWith('/'))
          .toList();
      if (hit.isNotEmpty) return hit.last;
    } catch (_) {}
    return _scanPath(name, const ['']);
  }

  /// Windows: the app already inherits the user/system PATH, so use `where`
  /// (which honors PATHEXT), then fall back to a manual PATH+PATHEXT scan.
  Future<String?> _resolveWindows(String name) async {
    try {
      final res = await Process.run('where', [name]);
      if (res.exitCode == 0) {
        final hit = res.stdout
            .toString()
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();
        if (hit.isNotEmpty) return hit.first;
      }
    } catch (_) {}
    final exts = (Platform.environment['PATHEXT'] ?? '.COM;.EXE;.BAT;.CMD')
        .split(';')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return _scanPath(name, [...exts, '']);
  }

  /// Walks `PATH` looking for `name` with any of [exts] (in order).
  String? _scanPath(String name, List<String> exts) {
    final entries = (Platform.environment['PATH'] ?? '')
        .split(Platform.isWindows ? ';' : ':')
        .map((d) => d.trim())
        .where((d) => d.isNotEmpty);
    for (final dir in entries) {
      for (final ext in exts) {
        final candidate = File('$dir${Platform.pathSeparator}$name$ext');
        if (candidate.existsSync()) return candidate.path;
      }
    }
    return null;
  }

  Future<Process> start(
    String executable,
    List<String> args, {
    required String workingDir,
    Map<String, String>? extraEnv,
  }) {
    return Process.start(
      executable,
      args,
      workingDirectory: workingDir,
      environment: {...Platform.environment, ...?extraEnv},
      runInShell: needsShell,
    );
  }

  /// Stops [process] and everything it started. `Process.kill` ends only the
  /// process itself: the `cmd.exe` that [start] runs a `.cmd` shim in on
  /// Windows, or the shell script around a binary elsewhere, while the real
  /// CLI behind it carries on — calling its model and using quota — with no
  /// one waiting for the answer.
  Future<void> killTree(Process process) async {
    try {
      if (Platform.isWindows) {
        final res = await Process.run('taskkill', [
          '/PID',
          '${process.pid}',
          '/T',
          '/F',
        ]);
        if (res.exitCode == 0) return;
      } else {
        // Children are listed before the parent goes: once it is gone they
        // belong to init and can no longer be found through it.
        final descendants = await _descendants(process.pid);
        for (final pid in descendants.reversed) {
          Process.killPid(pid);
        }
      }
    } on Exception catch (_) {
      // Best effort: the process itself is still stopped below.
    }
    process.kill();
  }

  /// The pids below [pid], each parent before its children.
  Future<List<int>> _descendants(int pid) async {
    final res = await Process.run('pgrep', ['-P', '$pid']);
    final found = <int>[];
    for (final line in res.stdout.toString().split('\n')) {
      final child = int.tryParse(line.trim());
      if (child == null) continue;
      found
        ..add(child)
        ..addAll(await _descendants(child));
    }
    return found;
  }
}
