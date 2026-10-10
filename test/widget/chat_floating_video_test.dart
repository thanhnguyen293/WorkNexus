import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/chat/domain/value_objects/message_content.dart';
import 'package:work_nexus/features/chat/presentation/providers/chat_video_playback.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_floating_video.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

const _thread = (accountId: 'zt', chatGid: 'c1');

/// Starts out floating a video of [_thread] (never initialized: no platform
/// player in tests).
class _FloatingPlayback extends ChatVideoPlaybackNotifier {
  @override
  ChatVideoPlayback? build() => ChatVideoPlayback(
    thread: _thread,
    messageGid: 'g1',
    file: const FileContent(fileId: 7, name: 'a.mp4', size: 1, time: 0),
    player: VideoPlayerController.file(File('a.mp4')),
    floating: true,
  );
}

void main() {
  Future<ProviderContainer> pump(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        chatVideoPlaybackProvider.overrideWith(_FloatingPlayback.new),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(
            variant: AppThemeVariant.light,
            surface: SurfaceStyle.outline,
            density: AppDensity.comfortable,
          ),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: ChatFloatingVideo(thread: _thread),
            ),
          ),
        ),
      ),
    );
    return container;
  }

  testWidgets('floats top-left, drags, and × stops it', (tester) async {
    final container = await pump(tester);
    final close = find.byIcon(PhosphorIconsLight.x);
    expect(close, findsOneWidget);
    final mini = find.byType(VideoPlayer);
    final start = tester.getTopLeft(mini);
    expect(start.dx, lessThan(400));
    expect(start.dy, lessThan(300));

    await tester.drag(mini, const Offset(120, 80));
    await tester.pump();
    expect(tester.getTopLeft(mini).dx, greaterThan(start.dx));

    await tester.tap(close);
    await tester.pump();
    expect(container.read(chatVideoPlaybackProvider), isNull);
    expect(find.byType(VideoPlayer), findsNothing);
  });
}
