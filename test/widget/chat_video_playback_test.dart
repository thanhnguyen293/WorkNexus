import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:work_nexus/features/chat/domain/value_objects/message_content.dart';
import 'package:work_nexus/features/chat/presentation/providers/chat_video_playback.dart';

/// A docked video that is not playing (never initialized: no platform
/// player in tests, so it reads as paused).
class _PausedPlayback extends ChatVideoPlaybackNotifier {
  @override
  ChatVideoPlayback? build() => ChatVideoPlayback(
    thread: (accountId: 'zt', chatGid: 'c1'),
    messageGid: 'g1',
    file: const FileContent(fileId: 7, name: 'a.mp4', size: 1, time: 0),
    player: VideoPlayerController.file(File('a.mp4')),
  );
}

void main() {
  test('a paused video stays docked when its message scrolls away', () {
    final container = ProviderContainer(
      overrides: [chatVideoPlaybackProvider.overrideWith(_PausedPlayback.new)],
    );
    addTearDown(container.dispose);

    container
        .read(chatVideoPlaybackProvider.notifier)
        .setFloating('g1', floating: true);

    expect(container.read(chatVideoPlaybackProvider)?.floating, isFalse);
  });
}
