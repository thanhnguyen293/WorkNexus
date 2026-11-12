import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/util/dropped_files.dart';
import 'package:work_nexus/features/chat/presentation/providers/chat_providers.dart';
import 'package:work_nexus/features/chat/presentation/providers/chat_staged_files_provider.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_staged_files.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

const ChatComposerKey _key = (
  chat: (accountId: 'acc', chatGid: 'g1'),
  inThread: false,
);

void main() {
  late ProviderContainer container;
  late List<List<DroppedFile>> sent;
  late int cleared;

  Future<void> pump(WidgetTester tester, List<DroppedFile> files) async {
    container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(chatStagedFilesProvider(_key).notifier).state = files;
    sent = [];
    cleared = 0;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          theme: buildAppTheme(
            variant: AppThemeVariant.light,
            surface: SurfaceStyle.outline,
            density: AppDensity.comfortable,
          ),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: Scaffold(
            body: ChatStagedFiles(
              draftKey: _key,
              onSend: sent.add,
              onCleared: () => cleared++,
            ),
          ),
        ),
      ),
    );
  }

  List<DroppedFile> staged() => container.read(chatStagedFilesProvider(_key));

  final a = (name: 'a.pdf', bytes: Uint8List.fromList([1]));
  final b = (name: 'b.zip', bytes: Uint8List.fromList([2]));

  testWidgets('Enter sends the waiting files and empties the input', (
    tester,
  ) async {
    await pump(tester, [a, b]);
    expect(find.text('a.pdf'), findsOneWidget);
    expect(find.text('b.zip'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(sent.single.map((f) => f.name), ['a.pdf', 'b.zip']);
    expect(staged(), isEmpty);
  });

  testWidgets('removing a file keeps the rest; removing the last clears', (
    tester,
  ) async {
    await pump(tester, [a, b]);

    await tester.tap(find.byIcon(LucideIcons.x300).first);
    await tester.pump();
    expect(staged().map((f) => f.name), ['b.zip']);
    expect(cleared, 0);

    await tester.tap(find.byIcon(LucideIcons.x300));
    await tester.pump();
    expect(staged(), isEmpty);
    expect(cleared, 1);
    expect(sent, isEmpty);
  });

  testWidgets('Esc removes them all without sending', (tester) async {
    await pump(tester, [a, b]);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(staged(), isEmpty);
    expect(cleared, 1);
    expect(sent, isEmpty);
  });
}
