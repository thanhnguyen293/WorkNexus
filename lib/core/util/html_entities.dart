/// Replaces HTML character references — named (`&quot;`, `&amp;`, …) and
/// numeric (`&#39;`, `&#x2F;`) — with the characters they stand for. ZenTao
/// returns titles HTML-escaped; unknown names are left as written.
String decodeHtmlEntities(String text) {
  if (!text.contains('&')) return text;
  return text.replaceAllMapped(_reference, (m) {
    final name = m[1];
    if (name != null) return _named[name] ?? m[0]!;
    final code = m[2] != null
        ? int.tryParse(m[2]!, radix: 16)
        : int.tryParse(m[3] ?? '');
    return code != null && code > 0 && code <= 0x10FFFF
        ? String.fromCharCode(code)
        : m[0]!;
  });
}

final _reference = RegExp(
  r'&(?:([a-zA-Z]+)|#[xX]([0-9a-fA-F]{1,6})|#([0-9]{1,7}));',
);

const _named = {
  'quot': '"',
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'apos': "'",
  'nbsp': ' ',
};
