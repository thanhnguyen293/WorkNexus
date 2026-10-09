/// The link typed into the editor's link dialog, made whole: a bare
/// `example.com/x` gains `https://`. Null when it is not a usable link (no
/// host, spaces, or an unknown scheme).
String? normalizeLinkUrl(String input) {
  final raw = input.trim();
  if (raw.isEmpty || raw.contains(RegExp(r'\s'))) return null;
  if (raw.startsWith('mailto:')) return raw.length > 7 ? raw : null;
  final withScheme = raw.contains('://') ? raw : 'https://$raw';
  final uri = Uri.tryParse(withScheme);
  if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
    return null;
  }
  // A host needs a dot (or is localhost) to be a real address.
  final host = uri.host;
  if (host.isEmpty || !(host.contains('.') || host == 'localhost')) {
    return null;
  }
  return withScheme;
}
