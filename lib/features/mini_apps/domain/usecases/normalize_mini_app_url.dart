/// Turns what was typed into the address a mini app opens, or null when it is
/// not a web address. A bare `example.com` gets `https://`; only `http` and
/// `https` pass, so `file:` or `javascript:` never reach the web view.
class NormalizeMiniAppUrl {
  const NormalizeMiniAppUrl();

  Uri? call(String input) {
    final text = input.trim();
    if (text.isEmpty || text.contains(RegExp(r'\s'))) return null;
    final hasScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:').hasMatch(text);
    // `localhost:3000` parses as scheme `localhost`; treat a port as a host.
    final looksLikeHostPort = RegExp(r'^[^/:]+:\d+').hasMatch(text);
    final withScheme = hasScheme && !looksLikeHostPort ? text : 'https://$text';
    final uri = Uri.tryParse(withScheme);
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return uri;
  }

  /// What an app added without a name is called: its site's host.
  String defaultName(Uri uri) => uri.host.replaceFirst(RegExp(r'^www\.'), '');
}
