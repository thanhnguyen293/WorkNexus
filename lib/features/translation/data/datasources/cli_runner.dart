import 'dart:io';

/// Runs a short command to completion; [Process.run] in production.
typedef RunProcess =
    Future<ProcessResult> Function(String executable, List<String> args);

/// Resolves CLI binaries (GUI apps on macOS don't inherit the shell PATH) and
/// spawns them. One instance is shared through the composition root, so a
/// binary is looked up once per session.
///
/// The platform, environment, process launcher and file check are injectable
/// so lookup can be tested for any OS from any OS.
class CliRunner {
  CliRunner({
    bool? isWindows,
    Map<String, String>? environment,
    RunProcess? runProcess,
    bool Function(String path)? fileExists,
  }) : _isWindows = isWindows ?? Platform.isWindows,
       _env = environment ?? Platform.environment,
       _run = runProcess ?? Process.run,
       _exists = fileExists ?? ((path) => File(path).existsSync());

  final bool _isWindows;
  final Map<String, String> _env;
  final RunProcess _run;
  final bool Function(String path) _exists;

  /// Whether spawned CLIs must go through a shell. On Windows the binary may be
  /// a `.cmd`/`.bat` shim (e.g. npm-installed `opencode`), which `CreateProcess`
  /// cannot launch directly — it needs `%COMSPEC% /c`.
  static bool get needsShell => Platform.isWindows;

  /// Binaries found so far, by name. Finding one spawns a login shell (which
  /// sources the user's whole profile) and that ran on every translation. A
  /// miss is looked up again, so a binary installed while the app runs is
  /// still found; a hit is checked to still exist, so one removed is not
  /// launched from a dead path.
  final _found = <String, String>{};

  Future<String?> resolve(String name, {String? override}) async {
    if (override != null && override.trim().isNotEmpty) return override.trim();
    if (_found[name] case final path? when _exists(path)) {
      return path;
    }
    final path = _isWindows
        ? await _resolveWindows(name)
        : await _resolveUnix(name);
    if (path != null) _found[name] = path;
    return path;
  }

  /// macOS/Linux: a GUI launch omits the interactive-shell PATH (nvm, asdf,
  /// Homebrew, `~/.local/bin`, …), so ask a login shell, then fall back to a
  /// direct PATH scan for non-interactive shells.
  Future<String?> _resolveUnix(String name) async {
    final shell = _env['SHELL'] ?? '/bin/zsh';
    try {
      final res = await _run(shell, ['-lic', 'command -v $name']);
      final hit = res.stdout
          .toString()
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.startsWith('/'))
          .toList();
      if (hit.isNotEmpty) return hit.last;
    } catch (_) {}
    return _scanPath(name, const [''], _pathDirs());
  }

  /// Windows: the app already inherits the user/system PATH, so use `where`,
  /// then fall back to a manual PATH+PATHEXT scan and the usual per-user
  /// install dirs (for a PATH changed after the app was started).
  ///
  /// Only hits with a PATHEXT extension count: next to `opencode.cmd`, npm
  /// installs an extension-less `opencode` — a POSIX `sh` script for Git Bash
  /// that `where` lists *first*. Launched through `cmd /c` that script never
  /// runs, so every `opencode` call failed and a logged-in OpenCode read as
  /// "not linked".
  Future<String?> _resolveWindows(String name) async {
    final exts = _pathExts();
    try {
      final res = await _run('where', [name]);
      if (res.exitCode == 0) {
        final hit = res.stdout
            .toString()
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty && _hasExt(l, exts))
            .toList();
        if (hit.isNotEmpty) return hit.first;
      }
    } catch (_) {}
    return _scanPath(name, exts, [..._pathDirs(), ..._windowsInstallDirs()]);
  }

  /// Executable extensions, lower-cased, in PATHEXT order.
  List<String> _pathExts() => (_env['PATHEXT'] ?? '.COM;.EXE;.BAT;.CMD')
      .split(';')
      .map((e) => e.trim().toLowerCase())
      .where((e) => e.isNotEmpty)
      .toList();

  static bool _hasExt(String path, List<String> exts) {
    final lower = path.toLowerCase();
    return exts.any(lower.endsWith);
  }

  List<String> _pathDirs() => (_env['PATH'] ?? '')
      .split(_isWindows ? ';' : ':')
      .map((d) => d.trim())
      .where((d) => d.isNotEmpty)
      .toList();

  /// Where npm (global), Scoop and WinGet put per-user command shims.
  List<String> _windowsInstallDirs() {
    final appData = _env['APPDATA'];
    final profile = _env['USERPROFILE'];
    final localAppData = _env['LOCALAPPDATA'];
    return [
      if (appData != null && appData.isNotEmpty) '$appData\\npm',
      if (profile != null && profile.isNotEmpty) '$profile\\scoop\\shims',
      if (localAppData != null && localAppData.isNotEmpty)
        '$localAppData\\Microsoft\\WinGet\\Links',
    ];
  }

  /// Walks [dirs] looking for `name` with any of [exts] (in order).
  String? _scanPath(String name, List<String> exts, List<String> dirs) {
    final sep = _isWindows ? '\\' : '/';
    for (final dir in dirs) {
      for (final ext in exts) {
        final candidate = '$dir$sep$name$ext';
        if (_exists(candidate)) return candidate;
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
