import 'dart:convert';

import '../domain/adapters/translation_service.dart';

/// Prompts and reply parsing shared by every translation backend, so a ticket
/// or chat message is asked for the same way whichever one runs it.
String ticketPrompt(TicketSource s, String languageName) =>
    'Translate this software ticket into natural, technical $languageName. '
    'Preserve code, identifiers, file paths, URLs and Markdown. '
    'Return ONLY a JSON object with keys "title" and "body".\n'
    'Title: <<<${s.title}>>>\nBody: <<<${s.body}>>>';

String textPrompt(String text, String languageName) =>
    'Translate this chat message into natural $languageName. '
    'Preserve code, identifiers, URLs, emoji, @mentions and Markdown. '
    'Return ONLY the translation, with no preface or quotes.\n'
    'Message: <<<$text>>>';

/// The `{"title", "body"}` object in a model reply, which may wrap it in prose
/// or a code fence; null when there is none.
Map<String, dynamic>? extractTicketJson(String out) {
  final start = out.indexOf('{');
  final end = out.lastIndexOf('}');
  if (start < 0 || end <= start) return null;
  try {
    final decoded = jsonDecode(out.substring(start, end + 1));
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (_) {
    return null;
  }
}
