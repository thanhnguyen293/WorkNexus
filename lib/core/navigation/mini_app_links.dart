import 'package:flutter_riverpod/legacy.dart';

/// A mini app a tapped link can open in: its id and the site it shows.
class MiniAppLinkTarget {
  const MiniAppLinkTarget({required this.id, required this.host});

  final String id;
  final String host;
}

/// The mini apps links may open in, kept current by the mini apps feature
/// (shared here so other features route links without importing it).
final miniAppLinkTargetsProvider = StateProvider<List<MiniAppLinkTarget>>(
  (ref) => const [],
);

/// A link a mini app was asked to open. [seq] tells a repeated request for the
/// same address from one already handled.
class MiniAppNavigation {
  const MiniAppNavigation({
    required this.id,
    required this.url,
    required this.seq,
  });

  final String id;
  final String url;
  final int seq;
}

final miniAppNavigationProvider = StateProvider<MiniAppNavigation?>(
  (ref) => null,
);

/// The id of the mini app that shows [url]'s site, or null. The site's own
/// host wins over one of its parents, so `a.example.com` prefers an app added
/// for `a.example.com` to one added for `example.com`. Only web links match.
String? findMiniAppForLink(List<MiniAppLinkTarget> targets, String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    return null;
  }
  final host = uri.host.toLowerCase();
  if (host.isEmpty) return null;
  MiniAppLinkTarget? best;
  for (final t in targets) {
    final h = t.host.toLowerCase();
    if (host != h && !host.endsWith('.$h')) continue;
    if (best == null || h.length > best.host.length) best = t;
  }
  return best?.id;
}
