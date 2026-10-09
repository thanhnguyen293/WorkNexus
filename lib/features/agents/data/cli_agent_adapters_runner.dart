part of 'cli_agent_adapters.dart';

/// Resolves CLI binaries (GUI apps on macOS don't inherit the shell PATH) and
/// spawns them. The resolved path can be overridden per agent in Settings.
class AgentRunner {
  const AgentRunner();

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
}
