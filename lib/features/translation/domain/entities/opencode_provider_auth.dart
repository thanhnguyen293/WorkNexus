/// How one OpenCode provider is signed in, as OpenCode's own credential store
/// records it. The key itself never leaves the data layer: only
/// [keyPreview] — a masked tail such as `••••••a1b2` — does.
class OpenCodeProviderAuth {
  const OpenCodeProviderAuth({required this.linked, this.keyPreview});

  static const none = OpenCodeProviderAuth(linked: false);

  /// Whether OpenCode has any credentials for the provider.
  final bool linked;

  /// Set for an API key; null for a login only `opencode auth login` can
  /// refresh (OAuth), or when [linked] is false.
  final String? keyPreview;
}
