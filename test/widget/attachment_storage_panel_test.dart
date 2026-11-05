import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/di/locator.dart';
import 'package:work_nexus/core/domain/adapters/ticket_detail_service.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/l10n/app_localizations.dart';
import 'package:work_nexus/shared/detail/presentation/widgets/attachment_storage_panel.dart';

class _MockService extends Mock implements TicketDetailService {}

void main() {
  late _MockService service;

  setUp(() async {
    service = _MockService();
    await getIt.reset();
    getIt.registerSingleton<TicketDetailService>(service);
  });

  tearDown(getIt.reset);

  testWidgets('shows the usage and clears it after confirming', (tester) async {
    var bytes = 3 * 1024 * 1024;
    when(service.attachmentStorageBytes).thenAnswer((_) async => Ok(bytes));
    when(service.clearAttachmentStorage).thenAnswer((_) async {
      bytes = 0;
      return const Ok(null);
    });
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildAppTheme(
            variant: AppThemeVariant.dark,
            surface: SurfaceStyle.outline,
            density: AppDensity.comfortable,
          ),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const Scaffold(body: AttachmentStoragePanel()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Using 3.0 MB'), findsOneWidget);

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    // The confirm dialog's own "Clear".
    await tester.tap(find.text('Clear').last);
    await tester.pumpAndSettle();

    verify(service.clearAttachmentStorage).called(1);
    expect(find.text('Using 0 B'), findsOneWidget);
  });
}
