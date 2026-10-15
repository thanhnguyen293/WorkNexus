/// GitLab marks a merge request as a draft by a title prefix — the REST update
/// endpoint has no `draft` flag — so toggling it means editing the title. The
/// prefixes are the ones GitLab itself recognizes.
final _draftPrefix = RegExp(
  r'^\s*(\[draft\]|\(draft\)|draft:|draft\s+-|\[wip\]|wip:)\s*',
  caseSensitive: false,
);

/// [title] with any draft prefix removed ("Draft: Fix x" → "Fix x").
String readyTitle(String title) {
  var out = title;
  while (_draftPrefix.hasMatch(out)) {
    out = out.replaceFirst(_draftPrefix, '');
  }
  return out;
}

/// [title] carrying GitLab's canonical draft prefix, exactly once.
String draftTitle(String title) => 'Draft: ${readyTitle(title)}';
