import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/chat/domain/value_objects/message_content.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_image_viewer_bar.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

void main() {
  testWidgets('every action is one click on the bar', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var rotated = 0;
    final transform = TransformationController();
    addTearDown(transform.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        theme: buildAppTheme(
          variant: AppThemeVariant.dark,
          surface: SurfaceStyle.outline,
          density: AppDensity.comfortable,
        ),
        home: Scaffold(
          body: ChatImageViewerBar(
            image:
                const MessageContent.image(
                      fileId: 1,
                      name: 'cat.jpg',
                      size: 1000,
                      time: 0,
                    )
                    as ImageContent,
            position: '1 / 1',
            transform: transform,
            onZoomIn: () {},
            onZoomOut: () {},
            onFit: () {},
            onRotate: () => rotated++,
            onCopy: () {},
            onSave: () {},
            onSaveSticker: () {},
            onOpenExternally: () {},
            onClose: () {},
          ),
        ),
      ),
    );

    expect(find.byIcon(LucideIcons.zoomIn300), findsOneWidget);
    expect(find.byIcon(LucideIcons.download300), findsOneWidget);
    expect(find.byIcon(LucideIcons.ellipsis300), findsNothing);

    await tester.tap(find.byIcon(LucideIcons.rotateCw300));
    await tester.pumpAndSettle();
    expect(rotated, 1);
  });
}
