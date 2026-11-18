import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../core/error/result.dart';
import '../../../../core/settings/app_settings.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_summary.dart';
import '../../domain/repositories/chat_ai_text_generator.dart';
import '../../domain/usecases/rewrite_chat_draft.dart';
import '../../domain/usecases/should_offer_chat_summary.dart';
import '../../domain/usecases/suggest_chat_replies.dart';
import '../../domain/usecases/summarize_chat.dart';
import '../../domain/value_objects/chat_draft_tone.dart';
import 'chat_providers.dart';

/// The most messages a summary reads, however many are unread.
const kChatSummaryMaxMessages = 300;

/// How many of the latest messages reply ideas and rewrites look at.
const _kReplyContextMessages = 20;

/// Who is who for a prompt: the user's own name and everyone else's by id.
typedef ChatAiPeople = ({String selfName, String Function(int) nameOf});

/// The names a prompt quotes for an account's chats. Watched by the widgets
/// that start an AI run, so the users are loaded by the time one starts.
final chatAiPeopleProvider = Provider.autoDispose.family<ChatAiPeople, String>((
  ref,
  accountId,
) {
  final users = ref.watch(chatUsersProvider(accountId)).value ?? const {};
  final self = ref.watch(chatSelfUserIdProvider(accountId)).value;
  final selfName = users[self]?.realname;
  return (
    selfName: selfName == null || selfName.isEmpty ? 'Me' : selfName,
    nameOf: (id) {
      final name = users[id]?.realname;
      return name == null || name.isEmpty ? 'User $id' : name;
    },
  );
});

/// How many messages were unread when the chat opened, before opening marked
/// them read: what the catch-up banner offers to summarize.
final chatUnreadOnOpenProvider = StateProvider.autoDispose
    .family<int, ChatThreadKey>((ref, key) => 0);

/// The catch-up banner was dismissed for this visit to the chat.
final chatCatchUpDismissedProvider = StateProvider.autoDispose
    .family<bool, ChatThreadKey>((ref, key) => false);

/// Whether opening the chat offers to summarize what came in meanwhile.
final chatOffersCatchUpProvider = Provider.autoDispose
    .family<bool, ChatThreadKey>((ref, key) {
      final unread = ref.watch(chatUnreadOnOpenProvider(key));
      return const ShouldOfferChatSummary()(unread: unread) &&
          !ref.watch(chatCatchUpDismissedProvider(key));
    });

/// Which messages a summary covers: the ones that were unread, or the
/// latest [count].
typedef ChatSummaryScope = ({bool unread, int count});

/// The scope picked in the assistant panel: the unread messages when there
/// are enough of them to be worth it, the latest 50 otherwise.
final chatSummaryScopeProvider = StateProvider.autoDispose
    .family<ChatSummaryScope, ChatThreadKey>((ref, key) {
      final unread = ref.read(chatUnreadOnOpenProvider(key));
      return const ShouldOfferChatSummary()(unread: unread)
          ? (unread: true, count: unread)
          : (unread: false, count: 50);
    });

/// The model pinned in Settings for the AI backend; null leaves it its own.
String? _model(Ref ref) {
  final model = ref.read(appSettingsProvider).translationModel;
  return model.isEmpty ? null : model;
}

/// The newest [limit] stored messages of [thread], oldest first or not —
/// the transcript orders them itself.
Future<List<ChatMessage>> _latest(Ref ref, ChatThreadKey thread, int limit) =>
    ref
        .read(chatRepositoryProvider)
        .watchMessages(
          thread.accountId,
          thread.chatGid,
          limit: limit,
          reactions: false,
        )
        .first;

/// The AI summary of a chat: null until one is asked for. Kept while the app
/// runs (not auto-disposed) on purpose: a summary costs a model call, so
/// closing and reopening the panel shows it again instead of paying for a
/// new one; "Summarize again" makes a fresh one.
final chatSummaryProvider =
    NotifierProvider.family<
      ChatSummaryController,
      AsyncValue<ChatSummary>?,
      ChatThreadKey
    >(ChatSummaryController.new);

class ChatSummaryController extends Notifier<AsyncValue<ChatSummary>?> {
  ChatSummaryController(this.thread);

  final ChatThreadKey thread;

  /// Bumped by each run and by [cancel], so a run that was cancelled or
  /// overtaken leaves the state alone when it finishes.
  var _run = 0;

  String get _key => 'chat-summary:${thread.accountId}:${thread.chatGid}';

  @override
  AsyncValue<ChatSummary>? build() => null;

  /// Summarizes the latest [count] messages in [languageName].
  Future<void> summarize({
    required int count,
    required String languageName,
    required ChatAiPeople people,
  }) async {
    final run = ++_run;
    state = const AsyncLoading();
    final messages = await _latest(
      ref,
      thread,
      count.clamp(1, kChatSummaryMaxMessages),
    );
    final result = await getIt<SummarizeChat>()(
      messages,
      key: _key,
      languageName: languageName,
      selfName: people.selfName,
      nameOf: people.nameOf,
      model: _model(ref),
    );
    if (!ref.mounted || run != _run) return;
    state = switch (result) {
      Ok(:final value) => AsyncData(value),
      Err(:final failure) => AsyncError(failure.message, StackTrace.current),
    };
  }

  /// Stops a summary in progress and forgets it.
  Future<void> cancel() async {
    _run++;
    state = null;
    await getIt<ChatAiTextGenerator>().cancel(_key);
  }
}

/// Reply ideas for a composer: null until asked for, cleared once one is
/// picked or the list is closed.
final chatReplySuggestionsProvider = NotifierProvider.autoDispose
    .family<
      ChatReplySuggestionsController,
      AsyncValue<List<String>>?,
      ChatComposerKey
    >(ChatReplySuggestionsController.new);

class ChatReplySuggestionsController
    extends Notifier<AsyncValue<List<String>>?> {
  ChatReplySuggestionsController(this.composer);

  final ChatComposerKey composer;
  var _run = 0;
  var _busy = false;

  String get _key =>
      'chat-replies:${composer.chat.accountId}:${composer.chat.chatGid}';

  @override
  AsyncValue<List<String>>? build() {
    // A composer that goes away stops what it asked for.
    ref.onDispose(_stop);
    return null;
  }

  void _stop() {
    if (_busy) getIt<ChatAiTextGenerator>().cancel(_key);
  }

  Future<void> suggest(ChatAiPeople people) async {
    final run = ++_run;
    _busy = true;
    state = const AsyncLoading();
    final messages = await _latest(ref, composer.chat, _kReplyContextMessages);
    final result = await getIt<SuggestChatReplies>()(
      messages,
      key: _key,
      selfName: people.selfName,
      nameOf: people.nameOf,
      model: _model(ref),
    );
    if (run == _run) _busy = false;
    if (!ref.mounted || run != _run) return;
    state = switch (result) {
      Ok(:final value) => AsyncData(value),
      Err(:final failure) => AsyncError(failure.message, StackTrace.current),
    };
  }

  /// Closes the list, stopping a run still in progress.
  void clear() {
    _stop();
    _run++;
    _busy = false;
    state = null;
  }
}

/// A rewrite of a composer's draft in progress (true) or not.
final chatDraftRewriteProvider = NotifierProvider.autoDispose
    .family<ChatDraftRewriteController, bool, ChatComposerKey>(
      ChatDraftRewriteController.new,
    );

class ChatDraftRewriteController extends Notifier<bool> {
  ChatDraftRewriteController(this.composer);

  final ChatComposerKey composer;

  String get _key =>
      'chat-rewrite:${composer.chat.accountId}:${composer.chat.chatGid}';

  var _busy = false;

  @override
  bool build() {
    ref.onDispose(() {
      if (_busy) getIt<ChatAiTextGenerator>().cancel(_key);
    });
    return false;
  }

  /// [draft] rewritten in [tone], in the light of the latest messages.
  Future<Result<String>> rewrite(
    String draft, {
    required ChatDraftTone tone,
    required ChatAiPeople people,
  }) async {
    state = _busy = true;
    final context = await _latest(ref, composer.chat, _kReplyContextMessages);
    final result = await getIt<RewriteChatDraft>()(
      draft,
      tone: tone,
      key: _key,
      context: context,
      selfName: people.selfName,
      nameOf: people.nameOf,
      model: _model(ref),
    );
    _busy = false;
    if (ref.mounted) state = false;
    return result;
  }
}
