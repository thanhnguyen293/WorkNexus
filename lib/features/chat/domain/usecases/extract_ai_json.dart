import 'dart:convert';

/// The JSON object (or, with [array], list) in a model's reply, which may wrap
/// it in prose or a code fence; null when there is none or it does not parse.
Object? extractAiJson(String reply, {bool array = false}) {
  final open = array ? '[' : '{';
  final close = array ? ']' : '}';
  final start = reply.indexOf(open);
  final end = reply.lastIndexOf(close);
  if (start < 0 || end <= start) return null;
  try {
    return jsonDecode(reply.substring(start, end + 1));
  } on FormatException {
    return null;
  }
}

/// The non-blank strings of a JSON list; anything else gives none.
List<String> jsonStrings(Object? value) => value is List
    ? [
        for (final item in value)
          if (item is String && item.trim().isNotEmpty) item.trim(),
      ]
    : const [];
