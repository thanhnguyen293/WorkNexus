import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/settings/app_settings.dart';
import 'package:work_nexus/core/settings/chat_privacy.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/widgets/privacy_mask.dart';
import 'package:work_nexus/features/chat/domain/value_objects/chat_privacy_part.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_privacy_mask.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_privacy_settings.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_privacy_shortcut.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

Future<ProviderContainer> _pump(WidgetTester tester, Widget body) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        theme: buildAppTheme(
          variant: AppThemeVariant.light,
          surface: SurfaceStyle.outline,
          density: AppDensity.comfortable,
        ),
        home: Scaffold(
          body: SingleChildScrollView(child: SizedBox(width: 360, child: body)),
        ),
      ),
    ),
  );
  return container;
}

double _opacityOver(WidgetTester tester, String text) => tester
    .widget<Opacity>(
      find.ancestor(of: find.text(text), matching: find.byType(Opacity)),
    )
    .opacity;

void main() {
  testWidgets('the mode switch turns hiding on; the parts only change '
      'while it is on', (tester) async {
    final container = await _pump(tester, const ChatPrivacySettings());
    ChatPrivacy privacy() => container.read(appSettingsProvider).chatPrivacy;

    await tester.tap(find.text('Fade out messages'));
    await tester.pump();
    expect(privacy().hideMessages, isTrue, reason: 'disabled while off');

    await tester.tap(find.text('Privacy mode'));
    await tester.pump();
    expect(privacy().enabled, isTrue);

    await tester.tap(find.text('Fade out messages'));
    await tester.pump();
    expect(privacy(), const ChatPrivacy(enabled: true, hideMessages: false));
  });

  testWidgets('chat parts hide as the settings say', (tester) async {
    final container = await _pump(
      tester,
      const Column(
        children: [
          ChatPrivacyText('Alice', part: ChatPrivacyPart.identity),
          ChatPrivacyText('24 members', part: null),
          ChatPrivacyFade(child: Text('msg')),
        ],
      ),
    );
    expect(find.text('Alice'), findsOneWidget);
    expect(_opacityOver(tester, 'msg'), 1);

    final settings = container.read(appSettingsProvider.notifier);
    settings.setChatPrivacy(const ChatPrivacy(enabled: true));
    await tester.pump();
    expect(find.text('Alice'), findsNothing);
    expect(find.text(kPrivacyMaskText), findsOneWidget);
    expect(find.text('24 members'), findsOneWidget, reason: 'no part');
    expect(_opacityOver(tester, 'msg'), lessThan(0.5));

    settings.setChatPrivacy(
      const ChatPrivacy(enabled: true, hideIdentities: false),
    );
    await tester.pump();
    expect(find.text('Alice'), findsOneWidget);
  });

  testWidgets('Ctrl+Shift+H flips the mode and keeps the picked parts', (
    tester,
  ) async {
    final container = await _pump(tester, const ChatPrivacyShortcut());
    container
        .read(appSettingsProvider.notifier)
        .setChatPrivacy(const ChatPrivacy(hidePreviews: false));
    ChatPrivacy privacy() => container.read(appSettingsProvider).chatPrivacy;

    Future<void> press() async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
    }

    await press();
    expect(privacy(), const ChatPrivacy(enabled: true, hidePreviews: false));

    await press();
    expect(privacy().enabled, isFalse);

    // Without Shift it is someone else's shortcut.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(privacy().enabled, isFalse);
  });
}
