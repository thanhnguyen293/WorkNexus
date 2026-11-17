import 'dart:io';

/// Runs a program and returns its stdout, or null when it fails.
typedef RunProcess =
    Future<String?> Function(String executable, List<String> args);

/// Finds the `node` an AI tool should run the MCP server with.
///
/// An app opened from the Dock / Start menu does not inherit the user's shell
/// `PATH` (Homebrew, nvm, …), so on macOS and Linux it asks the user's login
/// shell, then falls back to the usual install places.
class NodeRuntimeProbe {
  NodeRuntimeProbe({
    RunProcess? run,
    Map<String, String>? environment,
    bool? isWindows,
  }) : _run = run ?? _runProcess,
       _env = environment ?? Platform.environment,
       _isWindows = isWindows ?? Platform.isWindows;

  final RunProcess _run;
  final Map<String, String> _env;
  final bool _isWindows;

  static const _unixFallbacks = [
    '/opt/homebrew/bin/node',
    '/usr/local/bin/node',
    '/usr/bin/node',
  ];

  /// The first `node` found and its `--version`, or null.
  Future<({String path, String version})?> find() async {
    for (final path in await _candidates()) {
      final version = (await _run(path, ['--version']))?.trim();
      if (version != null && version.startsWith('v')) {
        return (path: path, version: version);
      }
    }
    return null;
  }

  Future<List<String>> _candidates() async {
    if (_isWindows) {
      return _lines(await _run('where', ['node']));
    }
    final shell = _env['SHELL'] ?? '/bin/sh';
    // A login shell has the profile's PATH; only if that has no node, an
    // interactive one, which also reads the rc file nvm usually sets up in.
    var fromShell = await _shellNode(shell, '-lc');
    if (fromShell.isEmpty) fromShell = await _shellNode(shell, '-lic');
    return {...fromShell, ..._unixFallbacks}.toList();
  }

  Future<List<String>> _shellNode(String shell, String flags) async {
    final out = await _run(shell, [flags, 'command -v node']);
    return _lines(out).where((p) => p.startsWith('/')).toList();
  }

  static List<String> _lines(String? out) => (out ?? '')
      .split(RegExp(r'\r?\n'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  static Future<String?> _runProcess(
    String executable,
    List<String> args,
  ) async {
    try {
      final result = await Process.run(
        executable,
        args,
      ).timeout(const Duration(seconds: 5));
      return result.exitCode == 0 ? result.stdout as String : null;
    } on Exception {
      // Not installed, not executable, or hung: not a usable node.
      return null;
    }
  }
}
