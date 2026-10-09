import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/util/dropped_files.dart';
import 'package:work_nexus/core/widgets/file_drop_target.dart';

/// Plays what the desktop_drop plugin sends from the OS.
Future<void> _fromOs(WidgetTester tester, String method, Object args) =>
    tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'desktop_drop',
      const StandardMethodCodec().encodeMethodCall(MethodCall(method, args)),
      (_) {},
    );

void main() {
  testWidgets('outlines while files hover and hands over what is dropped', (
    tester,
  ) async {
    final dir = Directory.systemTemp.createTempSync('drop_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/notes.txt')..writeAsStringSync('hello');
    List<DroppedFile>? dropped;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(
          variant: AppThemeVariant.light,
          surface: SurfaceStyle.outline,
          density: AppDensity.comfortable,
        ),
        home: Scaffold(
          body: FileDropTarget(
            hint: 'Drop files to send',
            onDrop: (files) async => dropped = files,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    double overlay() =>
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;
    expect(overlay(), 0);

    final center = tester.getCenter(find.byType(FileDropTarget));
    await _fromOs(tester, 'entered', [center.dx, center.dy]);
    await tester.pump();
    expect(overlay(), 1);
    expect(find.text('Drop files to send'), findsOneWidget);

    await tester.runAsync(() async {
      await _fromOs(tester, 'performOperation', [file.path]);
      // Reading the file happens off the test clock.
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    expect(overlay(), 0);
    expect(dropped?.single.name, 'notes.txt');
    expect(String.fromCharCodes(dropped!.single.bytes), 'hello');
  });
}
