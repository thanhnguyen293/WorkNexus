import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/app/shell/storage_dialog.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_cache_usage.dart';
import 'package:work_nexus/features/chat/presentation/providers/chat_providers.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

void main() {
  testWidgets('chat files and local data share one dialog', (tester) async {
    // A short window: the dialog must fit without overflowing.
    tester.view.physicalSize = const Size(900, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatCacheUsageProvider.overrideWith(
            (ref) async =>
                const Ok(ChatCacheUsage(totalBytes: 0, limitBytes: 0)),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          theme: buildAppTheme(
            variant: AppThemeVariant.light,
            surface: SurfaceStyle.outline,
            density: AppDensity.comfortable,
          ),
          home: const Scaffold(body: StorageDialog()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Storage & cache'), findsOneWidget);
    expect(find.text('Downloaded chat files'), findsOneWidget);
    expect(find.text('Local database'), findsOneWidget);
    expect(find.text('Clear all'), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(4));
  });
}
