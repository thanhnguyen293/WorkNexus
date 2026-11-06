/// A browser whose cookies can be brought into the mini apps. The Chromium
/// ones share one way of keeping them; Firefox and Safari each have their own.
enum CookieBrowser {
  chrome,
  edge,
  brave,
  arc,
  firefox,
  safari;

  bool get isChromium => switch (this) {
    chrome || edge || brave || arc => true,
    firefox || safari => false,
  };
}
