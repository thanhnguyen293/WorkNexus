/// A formatting the composer's Markdown toolbar applies to the selection.
enum MarkdownFormat {
  bold,
  italic,
  underline,
  strikethrough,
  code,
  heading,
  quote,
  bulletList,
  numberedList,
  indent,
  outdent,
  clear,
}

/// Text being edited and its selection ([start] == [end] is a caret).
typedef MarkdownEdit = ({String text, int start, int end});
