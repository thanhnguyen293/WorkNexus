/// Second-level labels under which a country domain hands out names
/// (`example.com.vn`, `example.co.uk`), so the site is one label longer.
const _secondLevels = {'com', 'co', 'net', 'org', 'gov', 'edu', 'ac', 'or'};

/// The site a cookie [domain] belongs to, the name a user knows it by:
/// `.mail.google.com` → `google.com`, `shop.example.com.vn` →
/// `example.com.vn`. An address or a single-label host is its own site.
///
/// An approximation of the public suffix list, close enough to group what a
/// user picks from; a site under an unusual suffix only groups less.
String cookieSiteOf(String domain) {
  final host = domain.startsWith('.') ? domain.substring(1) : domain;
  final labels = host.toLowerCase().split('.');
  if (labels.length <= 2 || int.tryParse(labels.last) != null) {
    return host.toLowerCase();
  }
  final keep =
      labels.last.length == 2 &&
          _secondLevels.contains(labels[labels.length - 2])
      ? 3
      : 2;
  return labels.sublist(labels.length - keep).join('.');
}
