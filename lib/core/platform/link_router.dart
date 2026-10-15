/// Where a tapped web link may be taken before it falls through to the
/// browser, in the order they are tried.
enum LinkStage {
  /// Something the app shows itself (a ZenTao ticket in the detail panel).
  app,

  /// A mini app for the link's site.
  miniApp,
}

/// One step of the chain: opens [url] itself and says so, or declines so the
/// next step is tried.
abstract interface class LinkHandler {
  bool handle(String url);
}

/// Chain of responsibility for a tapped web link. Features register a handler
/// for their [LinkStage]; the router asks them in stage order until one opens
/// the link. The browser is not a stage: it is where a link ends up when
/// [route] returns false.
class LinkRouter {
  final _handlers = <LinkStage, LinkHandler>{};

  /// Makes [handler] the one for [stage], replacing an earlier one.
  void register(LinkStage stage, LinkHandler handler) =>
      _handlers[stage] = handler;

  /// Removes [handler] from [stage] — only if it is still the one there, so a
  /// late teardown cannot remove its replacement.
  void unregister(LinkStage stage, LinkHandler handler) {
    if (identical(_handlers[stage], handler)) _handlers.remove(stage);
  }

  /// Whether a handler opened [url]. Stages in [skip] are not asked, for a link
  /// that came from the app's own view of that very thing.
  bool route(String url, {Set<LinkStage> skip = const {}}) {
    for (final stage in LinkStage.values) {
      if (skip.contains(stage)) continue;
      if (_handlers[stage]?.handle(url) ?? false) return true;
    }
    return false;
  }
}

/// The app's router. Passed explicitly where a test needs its own.
final linkRouter = LinkRouter();
