import '../domain/value_objects/provider_type.dart';

/// A tag a rich-text editor's HTML is made of.
final _htmlTag = RegExp(
  r'<(?:p|div|br|span|img|strong|b|em|i|u|ul|ol|li|table|tr|td|th|h[1-6]|a|pre|code|blockquote|font|hr)\b[^>]*>',
  caseSensitive: false,
);

/// Whether a description or comment [text] from [provider] is HTML: ZenTao
/// keeps its rich-text editor's HTML as written; everything else is Markdown
/// (where an inline tag is still Markdown). A ZenTao text with no tags — plain
/// text, or Markdown stored before ZenTao bodies were kept as HTML — is shown
/// as Markdown until it is synced again.
bool isHtmlBody(ProviderType provider, String text) =>
    provider == ProviderType.zentao && _htmlTag.hasMatch(text);
