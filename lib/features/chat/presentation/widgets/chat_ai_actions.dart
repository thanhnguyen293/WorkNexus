import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/util/translation_languages.dart';
import '../../../../core/widgets/opencode_not_linked_dialog.dart';
import '../providers/chat_ai_providers.dart';
import '../providers/chat_providers.dart';
import 'chat_panels.dart';

/// The language summaries are written in: the one picked in the assistant
/// panel, else the app's.
String chatSummaryLanguageCode(BuildContext context, WidgetRef ref) =>
    ref.watch(chatSummaryLanguageProvider) ??
    translationLanguageFor(Localizations.localeOf(context).languageCode).code;

/// Opens the assistant beside chat [thread] and summarizes [scope] there,
/// once an AI backend is set up (otherwise explaining how to set one up).
/// [onStart] runs once the summary starts — the caller may then leave the
/// tree, as nothing after it needs the caller's `ref`.
Future<void> summarizeChat(
  BuildContext context,
  WidgetRef ref,
  ChatThreadKey thread,
  ChatSummaryScope scope, {
  VoidCallback? onStart,
}) async {
  openChatSidePanel(ref, thread, ChatSidePanel.assistant);
  ref.read(chatSummaryScopeProvider(thread).notifier).state = scope;
  final languageName = translationLanguageFor(
    ref.read(chatSummaryLanguageProvider) ??
        Localizations.localeOf(context).languageCode,
  ).englishName;
  final people = ref.read(chatAiPeopleProvider(thread.accountId));
  final summary = ref.read(chatSummaryProvider(thread).notifier);
  if (!await ensureOpenCodeLinked(context, ref)) return;
  onStart?.call();
  await summary.summarize(
    count: scope.count,
    languageName: languageName,
    people: people,
  );
}
