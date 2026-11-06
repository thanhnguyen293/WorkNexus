import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/platform/video_playback_hold.dart';

import '../../domain/value_objects/message_content.dart';
import 'chat_providers.dart';

/// The chat video playing right now. One at a time: starting another stops
/// it. While its message is scrolled out of view it plays on in a floating
/// mini player ([floating]).
@immutable
class ChatVideoPlayback {
  const ChatVideoPlayback({
    required this.thread,
    required this.messageGid,
    required this.file,
    required this.player,
    this.floating = false,
  });

  final ChatThreadKey thread;
  final String messageGid;
  final FileContent file;
  final VideoPlayerController player;
  final bool floating;

  ChatVideoPlayback copyWith({bool? floating}) => ChatVideoPlayback(
    thread: thread,
    messageGid: messageGid,
    file: file,
    player: player,
    floating: floating ?? this.floating,
  );
}

/// Owns the one in-chat video player, so it outlives the message tile that
/// started it (scrolled away, the video goes on floating).
class ChatVideoPlaybackNotifier extends Notifier<ChatVideoPlayback?> {
  /// The live player, kept apart from [state]: the dispose callback may not
  /// read state.
  VideoPlayerController? _player;

  /// Stops [_player] holding the network while it streams (see
  /// [holdWhileLoading]).
  void Function()? _release;

  @override
  ChatVideoPlayback? build() {
    ref.onDispose(() {
      _release?.call();
      _player?.dispose();
    });
    return null;
  }

  /// Plays [source] for [messageGid] (from [at]), stopping whatever played
  /// before: a local file, or a URL streamed while it downloads (see
  /// `ChatController.videoStream`). False when the platform player can't
  /// open it.
  Future<bool> start({
    required ChatThreadKey thread,
    required String messageGid,
    required FileContent file,
    required Uri source,
    Duration? at,
  }) async {
    stop();
    final player = await openChatVideo(source);
    if (player == null) return false;
    if (at != null) await player.seekTo(at);
    _player = player;
    // Background video downloads wait while this one still loads.
    _release = holdWhileLoading(player);
    state = ChatVideoPlayback(
      thread: thread,
      messageGid: messageGid,
      file: file,
      player: player,
    );
    await player.play();
    return true;
  }

  /// Floats the video of [messageGid] (its message left the view) or docks
  /// it back; nothing when another video, or none, plays. A paused video
  /// stays docked: the mini player is for one still playing.
  void setFloating(String messageGid, {required bool floating}) {
    // Called a frame late from widgets going away: the app may be too.
    if (!ref.mounted) return;
    final current = state;
    if (current == null || current.messageGid != messageGid) return;
    if (floating && !current.floating && !current.player.value.isPlaying) {
      return;
    }
    if (current.floating != floating) {
      state = current.copyWith(floating: floating);
    }
  }

  /// Stops the video when it is [thread]'s (that chat was closed).
  void stopIn(ChatThreadKey thread) {
    if (ref.mounted && state?.thread == thread) stop();
  }

  /// Stops and drops the player.
  void stop() {
    if (!ref.mounted) return;
    final current = state;
    if (current == null) return;
    _release?.call();
    _release = null;
    _player = null;
    state = null;
    // Once the frame that drops its views is drawn: a VideoPlayer still on
    // screen this frame must not hold a disposed controller.
    SchedulerBinding.instance
      ..addPostFrameCallback((_) => current.player.dispose())
      ..ensureVisualUpdate();
  }
}

/// A ready player for a chat video at [source] — a local file, or a URL
/// streamed while it downloads — or null when the platform player can't
/// open it.
Future<VideoPlayerController?> openChatVideo(Uri source) async {
  final player = source.isScheme('file')
      ? VideoPlayerController.file(File.fromUri(source))
      : VideoPlayerController.networkUrl(source);
  try {
    await player.initialize();
    return player;
  } on Exception {
    await player.dispose();
    return null;
  }
}

final chatVideoPlaybackProvider =
    NotifierProvider<ChatVideoPlaybackNotifier, ChatVideoPlayback?>(
      ChatVideoPlaybackNotifier.new,
    );
