import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_cache_usage.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_storage_meter.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

void main() {
  const mb = 1024 * 1024;

  testWidgets('shows the used total, the share of the limit and each kind', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(
          variant: AppThemeVariant.light,
          surface: SurfaceStyle.outline,
          density: AppDensity.comfortable,
        ),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: const Scaffold(
          body: ChatStorageMeter(
            limitBytes: 1000 * mb,
            usage: ChatCacheUsage(
              totalBytes: 110 * mb,
              limitBytes: 1000 * mb,
              chats: [
                ChatCacheChatUsage(
                  accountId: 'zt',
                  chatGid: 'c1',
                  bytes: 100 * mb,
                  imageBytes: 20 * mb,
                  videoBytes: 80 * mb,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('110.0 MB'), findsOneWidget);
    expect(find.text('/ 1000.0 MB'), findsOneWidget);
    expect(find.text('11%'), findsOneWidget);
    // Legend: photos, videos and the files no message points to; no files.
    expect(find.text('Photos'), findsOneWidget);
    expect(find.text('Videos'), findsOneWidget);
    expect(find.text('Other files'), findsOneWidget);
    expect(find.text('Files'), findsNothing);
  });
}
