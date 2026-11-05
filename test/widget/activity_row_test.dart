import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/activity_event.dart';
import 'package:work_nexus/core/domain/entities/provider_entity.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/l10n/app_localizations.dart';
import 'package:work_nexus/shared/detail/presentation/detail_providers.dart';
import 'package:work_nexus/shared/detail/presentation/widgets/attachment_video_frame.dart';
import 'package:work_nexus/shared/detail/presentation/widgets/comment_tile.dart';

void main() {
  const rec = TicketAttachment(
    id: '7',
    title: 'ScreenRecording_1.MP4',
    url: 'https://zt/file-download-7.mp4',
    extension: 'mp4',
  );

  const ticket = Ticket(
    id: 'zentao:bug:1',
    accountId: 'zt',
    projectId: 'zt:P',
    providerType: ProviderType.zentao,
    externalKey: '1',
    title: 't',
    body: 'b',
    priority: Priority.medium,
    status: UnifiedStatus.todo,
    providerStatus: 'active',
    sourceHash: 'h',
  );

  Future<List<TicketAttachment>> pumpRow(
    WidgetTester tester, {
    Ticket? withTicket,
  }) async {
    final opened = <TicketAttachment>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          attachmentThumbnailProvider.overrideWith((ref, key) async => null),
        ],
        child: MaterialApp(
          theme: buildAppTheme(
            variant: AppThemeVariant.dark,
            surface: SurfaceStyle.outline,
            density: AppDensity.comfortable,
          ),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: Scaffold(
            body: ActivityRow(
              ActivityEvent(
                id: 'a1',
                ticketId: 't',
                actor: 'Son',
                action: 'activated',
                at: DateTime(2026, 11, 4),
                attachments: const ['ScreenRecording_1.MP4', 'deleted.mp4'],
              ),
              files: const [rec],
              onOpenFile: opened.add,
              ticket: withTicket,
            ),
          ),
        ),
      ),
    );
    return opened;
  }

  testWidgets('a chip opens the ticket attachment it names', (tester) async {
    final opened = await pumpRow(tester);

    await tester.tap(find.text('ScreenRecording_1.MP4'));

    expect(opened, [rec]);
  });

  testWidgets('a chip whose file is gone stays a plain label', (tester) async {
    final opened = await pumpRow(tester);

    await tester.tap(find.text('deleted.mp4'));

    expect(opened, isEmpty);
  });

  testWidgets('with its ticket, a video draws as a frame that opens it', (
    tester,
  ) async {
    final opened = await pumpRow(tester, withTicket: ticket);
    await tester.pump();

    expect(find.byType(AttachmentVideoFrame), findsOneWidget);
    await tester.tap(find.byType(AttachmentVideoFrame));

    expect(opened, [rec]);
  });
}
