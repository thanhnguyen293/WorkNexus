import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_message.dart';
import 'package:work_nexus/features/chat/domain/value_objects/message_content.dart';
import 'package:work_nexus/features/chat/presentation/providers/chat_providers.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_file_body.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

void main() {
  const file = FileContent(fileId: 7, name: 'spec.pdf', size: 2048, time: 1);

  Future<void> pump(WidgetTester tester, {required bool cached}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatAttachmentCachedProvider((
            accountId: 'zt',
            content: file,
          )).overrideWith((ref) async => cached),
        ],
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
            body: SizedBox(
              width: 360,
              child: FileBody(
                accountId: 'zt',
                message: ChatMessage(
                  accountId: 'zt',
                  gid: 'g1',
                  chatGid: 'c1',
                  senderId: 2,
                  sentAt: DateTime(2026, 10, 10),
                  content: file,
                  isMine: false,
                ),
                file: file,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a downloaded file says so, with folder and save buttons', (
    tester,
  ) async {
    await pump(tester, cached: true);
    expect(find.text('On this device'), findsOneWidget);
    expect(find.byTooltip('Show in folder'), findsOneWidget);
    expect(find.byTooltip('Save as…'), findsOneWidget);
  });

  testWidgets('a file only on the server says so; no folder button yet', (
    tester,
  ) async {
    await pump(tester, cached: false);
    expect(find.text('Available on Cloud'), findsOneWidget);
    expect(find.byIcon(LucideIcons.cloudCheck300), findsOneWidget);
    expect(find.byTooltip('Show in folder'), findsNothing);
    expect(find.byTooltip('Save as…'), findsOneWidget);
  });
}
