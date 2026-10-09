import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart'
    show FlutterQuillLocalizations;
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/util/dropped_files.dart';
import 'package:work_nexus/core/widgets/html_editing_controller.dart';
import 'package:work_nexus/core/widgets/rich_text_editor.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

void main() {
  testWidgets('a dropped image goes inline, other files to the attachments', (
    tester,
  ) async {
    final dir = Directory.systemTemp.createTempSync('editor_drop');
    addTearDown(() => dir.deleteSync(recursive: true));
    final image = File('${dir.path}/shot.png')..writeAsBytesSync([1, 2, 3]);
    final text = File('${dir.path}/log.txt')..writeAsStringSync('log');
    final controller = HtmlEditingController();
    addTearDown(controller.dispose);
    final uploaded = <String>[];
    List<DroppedFile>? attached;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(
          variant: AppThemeVariant.light,
          surface: SurfaceStyle.outline,
          density: AppDensity.comfortable,
        ),
        localizationsDelegates: const [
          ...AppL10n.localizationsDelegates,
          FlutterQuillLocalizations.delegate,
        ],
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: RichTextEditor(
              controller: controller,
              // Shown through a loader so the test never goes to the network.
              imageLoader: (_) async => null,
              onUploadImage: (Uint8List bytes, String name) async {
                uploaded.add(name);
                return 'https://example.com/$name';
              },
              onDropFiles: (files) => attached = files,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final center = tester.getCenter(find.byType(RichTextEditor));
    Future<void> fromOs(String method, Object args) =>
        tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          'desktop_drop',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall(method, args),
          ),
          (_) {},
        );
    await fromOs('entered', [center.dx, center.dy]);
    await tester.runAsync(() async {
      await fromOs('performOperation', [image.path, text.path]);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    expect(uploaded, ['shot.png']);
    expect(attached?.map((f) => f.name), ['log.txt']);
    expect(controller.html, contains('https://example.com/shot.png'));
  });
}
