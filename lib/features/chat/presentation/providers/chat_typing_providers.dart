import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/settings/app_settings.dart';
import '../../domain/value_objects/chat_typing_signal.dart';
import '../../domain/value_objects/typing_roster.dart';
import 'chat_providers.dart';
import 'chat_typing_sender.dart';

/// The time typing entries are stamped and lapse by (overridden in tests,
/// whose timers run on fake time).
final chatTypingClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Who is typing where in one account's chats: the roster follows the live
/// signals and drops each entry once it lapses.
class ChatTypingNotifier extends Notifier<TypingRoster> {
  ChatTypingNotifier(this.accountId);

  final String accountId;
  Timer? _lapse;
  int? _self;

  late DateTime Function() _now;

  @override
  TypingRoster build() {
    _now = ref.watch(chatTypingClockProvider);
    _self = ref.watch(chatSelfUserIdProvider(accountId)).value;
    final signals = ref
        .watch(chatRepositoryProvider)
        .watchTyping(accountId)
        .listen(_onSignal);
    ref.onDispose(() {
      signals.cancel();
      _lapse?.cancel();
    });
    return const TypingRoster();
  }

  /// As if [signal] had arrived from the server (the debug typing button).
  void simulate(ChatTypingSignal signal) => _onSignal(signal);

  void _onSignal(ChatTypingSignal signal) =>
      _update(state.apply(signal, _now(), selfUserId: _self));

  void _update(TypingRoster next) {
    state = next;
    _lapse?.cancel();
    final at = next.nextExpiry;
    if (at == null) return;
    // Prunes as of the expiry it waited for: whatever lapsed by then goes,
    // however late the timer fires.
    _lapse = Timer(at.difference(_now()), () => _update(state.prune(at)));
  }
}

final chatTypingProvider = NotifierProvider.autoDispose
    .family<ChatTypingNotifier, TypingRoster, String>(ChatTypingNotifier.new);

/// The users typing in one chat, earliest to start first.
final chatTypingUsersProvider = Provider.autoDispose
    .family<List<int>, ChatThreadKey>(
      (ref, t) => ref.watch(
        chatTypingProvider(t.accountId).select((r) => r.typingIn(t.chatGid)),
      ),
    );

/// A [ChatTypingSender] for the composer of [t]. The controller is taken now
/// so the final "stopped" still goes out from the composer's `dispose`.
ChatTypingSender chatTypingSenderFor(WidgetRef ref, ChatThreadKey t) {
  final controller = ref.read(chatControllerProvider);
  return ChatTypingSender(
    // Best effort: a lost signal only delays or skips a hint that lapses on
    // its own within seconds, so a failure is not worth telling the user.
    send: (chat, {required typing}) =>
        unawaited(controller.sendTyping(chat, typing: typing)),
    chat: () => ref
        .read(chatConversationsProvider(t.accountId))
        .asData
        ?.value
        .where((c) => c.gid == t.chatGid)
        .firstOrNull,
    enabled: () => ref.read(appSettingsProvider).chatSendTypingStatus,
  );
}
