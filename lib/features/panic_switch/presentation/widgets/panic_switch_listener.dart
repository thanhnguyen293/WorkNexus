import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/debug/app_talker.dart';
import '../../../../core/error/result.dart';
import '../../../chat/domain/entities/chat_message.dart';
import '../../domain/usecases/list_panic_chats.dart';
import '../../domain/usecases/pick_default_panic_group.dart';
import '../../domain/value_objects/panic_trigger.dart';
import '../providers/panic_switch_config_controller.dart';
import '../providers/panic_switch_providers.dart';
import '../providers/panic_switch_runtime.dart';

/// Runs the panic switch for the whole app: listens for the sticker, keeps the
/// floating button up or down, and sends the sticker on its triple click.
/// Wraps the app shell so it works whichever view is open, and while the
/// window is hidden in the tray.
class PanicSwitchListener extends ConsumerStatefulWidget {
  const PanicSwitchListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PanicSwitchListener> createState() =>
      _PanicSwitchListenerState();
}

class _PanicSwitchListenerState extends ConsumerState<PanicSwitchListener> {
  StreamSubscription<ChatMessage>? _incoming;
  StreamSubscription<PanicTrigger>? _triggers;

  @override
  void initState() {
    super.initState();
    final runtime = ref.read(panicSwitchRuntimeProvider);
    _incoming = runtime.incoming.listen((m) => _log(runtime.onIncoming(m)));
    _triggers = runtime.overlay.triggers.listen(
      (trigger) => _log(runtime.onOverlayTriggered(trigger)),
    );
    ref.listenManual<bool>(
      panicOverlayVisibleProvider,
      (_, visible) => _log(runtime.showOverlay(visible)),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _incoming?.cancel();
    _triggers?.cancel();
    super.dispose();
  }

  // Both run in the background, with nobody looking at a screen to tell; the
  // log (Debug → Talker) is where a failure is seen.
  static Future<void> _log(Future<Result<void>> run) async {
    if ((await run).failureOrNull case final failure?) {
      appTalker.warning('Panic switch: ${failure.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(panicSwitchAccountProvider);
    final config = ref.watch(panicSwitchConfigProvider).asData?.value;
    if (account != null && config != null && config.chatGid == null) {
      // Until a group is picked, use the team's group once it is known.
      ref.listen<List<PanicChat>?>(
        panicChatsProvider((accountId: account.id, selfTitle: '')),
        (_, chats) {
          final gid = const PickDefaultPanicGroup()([
            for (final c in chats ?? const <PanicChat>[]) c.chat,
          ]);
          if (gid == null) return;
          _log(
            ref
                .read(panicSwitchConfigProvider.notifier)
                .edit((c) => c.chatGid == null ? c.copyWith(chatGid: gid) : c),
          );
        },
      );
    }
    return widget.child;
  }
}
