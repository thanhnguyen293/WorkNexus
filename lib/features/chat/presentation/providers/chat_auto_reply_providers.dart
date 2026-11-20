import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/error/result.dart';
import '../../../../core/platform/desktop_window_service.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/auto_reply_suggestions_preference.dart';
import '../../domain/usecases/should_auto_suggest_replies.dart';
import 'chat_ai_providers.dart';
import 'chat_providers.dart';
import 'sticker_suggestion_providers.dart';

final autoReplySuggestionsPreferenceProvider =
    Provider<AutoReplySuggestionsPreference>(
      (ref) => getIt<AutoReplySuggestionsPreference>(),
    );

/// Whether reply ideas come on their own while a chat is open (off until
/// the user turns it on in the ✨ menu). Kept for the app's lifetime.
class ChatAutoReplySetting extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async =>
      (await ref.read(autoReplySuggestionsPreferenceProvider).isEnabled())
          .valueOrNull ??
      false;

  /// Turns it on or off at once, then saves the choice; a failed save is
  /// returned for the caller to report.
  Future<Result<void>> setEnabled(bool enabled) {
    state = AsyncData(enabled);
    return ref.read(autoReplySuggestionsPreferenceProvider).setEnabled(enabled);
  }
}

final chatAutoReplySuggestionsProvider =
    AsyncNotifierProvider<ChatAutoReplySetting, bool>(ChatAutoReplySetting.new);

/// What automatic runs have been made in this app run, across chats: the
/// message each chat was last answered for, when, and every run of the last
/// hour. Kept alive on purpose — it is what holds the limits between chats.
class AutoReplyLedger {
  final _handled = <String, String>{};
  final _lastRun = <String, DateTime>{};
  final _runs = <DateTime>[];

  String? handledIn(String chat) => _handled[chat];

  DateTime? lastRunIn(String chat) => _lastRun[chat];

  int runsSince(DateTime since) {
    _runs.removeWhere((at) => at.isBefore(since));
    return _runs.length;
  }

  void record(String chat, String gid, DateTime at) {
    _handled[chat] = gid;
    _lastRun[chat] = at;
    _runs.add(at);
  }
}

final autoReplyLedgerProvider = Provider<AutoReplyLedger>(
  (ref) => AutoReplyLedger(),
);

/// Asks for reply ideas on its own for an open chat's main composer, as
/// [ShouldAutoSuggestReplies] allows — waiting for the chat to go quiet,
/// and stopping when the user types or another message comes.
final chatAutoReplyProvider = NotifierProvider.autoDispose
    .family<ChatAutoReplyController, void, ChatComposerKey>(
      ChatAutoReplyController.new,
    );

class ChatAutoReplyController extends Notifier<void> {
  ChatAutoReplyController(this.composer);

  final ChatComposerKey composer;
  static const _decide = ShouldAutoSuggestReplies();

  Timer? _timer;
  var _openedAt = DateTime.now();
  var _draftEmpty = true;

  /// The message the replies on show were asked for automatically.
  String? _shownFor;

  String get _chat => '${composer.chat.accountId}:${composer.chat.chatGid}';

  ChatReplySuggestionsController get _replies =>
      ref.read(chatReplySuggestionsProvider(composer).notifier);

  @override
  void build() {
    _openedAt = DateTime.now();
    ref.onDispose(() => _timer?.cancel());
    if (!(ref.watch(chatAutoReplySuggestionsProvider).value ?? false)) return;
    ref.listen<AsyncValue<ChatMessage?>>(
      chatLatestMessageProvider(composer.chat),
      (_, _) => _evaluate(),
    );
    // After build: evaluating may close the reply tray, another provider.
    _timer = Timer(Duration.zero, _evaluate);
  }

  /// The composer's text went from empty to typed or back.
  void draftChanged({required bool empty}) {
    if (empty == _draftEmpty) return;
    _draftEmpty = empty;
    if (!empty &&
        _replies.auto &&
        ref.read(chatReplySuggestionsProvider(composer)) is AsyncLoading) {
      _replies.clear();
      _shownFor = null;
    }
    _evaluate();
  }

  void _evaluate() {
    _timer?.cancel();
    if (!ref.mounted) return;
    final latest = ref.read(chatLatestMessageProvider(composer.chat)).value;
    // Ideas for an earlier message are stale once another one comes.
    if (_shownFor != null && latest?.gid != _shownFor && _replies.auto) {
      _replies.clear();
      _shownFor = null;
    }
    final ledger = ref.read(autoReplyLedgerProvider);
    final now = DateTime.now();
    final decision = _decide(
      latest: latest,
      draftEmpty: _draftEmpty,
      now: now,
      openedAt: _openedAt,
      handledGid: ledger.handledIn(_chat),
      lastRunInChat: ledger.lastRunIn(_chat),
      runsLastHour: ledger.runsSince(now.subtract(const Duration(hours: 1))),
    );
    switch (decision) {
      case AutoReplyWait(:final wait):
        _timer = Timer(wait, _evaluate);
      case AutoReplyRun():
        unawaited(_run(latest!));
      case AutoReplySkip():
        break;
    }
  }

  Future<void> _run(ChatMessage latest) async {
    // Ideas the user asked for stay as they are.
    if (ref.read(chatReplySuggestionsProvider(composer)) != null) return;
    if (!await _canRun()) {
      // Try again once the window is back in front (or the AI linked).
      if (ref.mounted) _timer = Timer(_decide.policy.quiet, _evaluate);
      return;
    }
    if (!ref.mounted ||
        !_draftEmpty ||
        ref.read(chatLatestMessageProvider(composer.chat)).value?.gid !=
            latest.gid) {
      return;
    }
    ref.read(autoReplyLedgerProvider).record(_chat, latest.gid, DateTime.now());
    _shownFor = latest.gid;
    await _replies.suggest(
      ref.read(chatAiPeopleProvider(composer.chat.accountId)),
      auto: true,
      contextMessages: _decide.policy.contextMessages,
    );
  }

  /// Only while the user looks at the window, and with the AI linked —
  /// never a dialog for a run the user did not ask for.
  Future<bool> _canRun() async {
    if (!await const DesktopWindowService().isFocused()) return false;
    if (!ref.mounted) return false;
    if (await ref.read(translatesWithApiKeyProvider.future)) return true;
    if (!ref.mounted) return false;
    return ref.read(openCodeAuthedProvider.future);
  }
}
