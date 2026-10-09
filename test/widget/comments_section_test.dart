import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/activity_event.dart';
import 'package:work_nexus/core/domain/entities/comment.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/task_detail/presentation/detail_providers.dart';
import 'package:work_nexus/features/task_detail/presentation/util/image_fallback.dart';
import 'package:work_nexus/features/task_detail/presentation/widgets/comments_section.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

void main() {
  const ticket = Ticket(
    id: 'zt:1',
    accountId: 'zt',
    projectId: 'zt:P',
    providerType: ProviderType.github,
    externalKey: '1',
    title: 't',
    body: 'b',
    priority: Priority.medium,
    status: UnifiedStatus.todo,
    providerStatus: 'open',
    sourceHash: 'h',
  );
  final at = DateTime(2026, 10, 5, 11);

  testWidgets('shows provider comments and activity, not local notes', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          commentsProvider(ticket.id).overrideWith(
            (ref) => Stream.value([
              Comment(
                id: 'c1',
                ticketId: ticket.id,
                authorName: 'Thanh',
                body: 'from the provider',
                createdAt: at,
              ),
              Comment(
                id: 'c2',
                ticketId: ticket.id,
                authorName: 'You',
                body: 'a local note',
                createdAt: at,
                origin: CommentOrigin.internalNote,
              ),
            ]),
          ),
          activityProvider(ticket.id).overrideWith(
            (ref) => Stream.value([
              ActivityEvent(
                id: 'a1',
                ticketId: ticket.id,
                actor: 'Thanh',
                action: 'edited',
                at: at.subtract(const Duration(hours: 1)),
              ),
            ]),
          ),
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
            body: SingleChildScrollView(
              child: CommentsSection(
                ticket: ticket,
                imageFallback: ImageFallback.forTicket(ticket, null),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('from the provider'), findsOneWidget);
    expect(find.textContaining('a local note'), findsNothing);
    expect(find.textContaining('edited', findRichText: true), findsOneWidget);
    // The composer posts to the provider only: no local-note switch.
    expect(find.text('Comment'), findsOneWidget);
    expect(find.text('Internal note'), findsNothing);
    expect(find.text('Post to provider'), findsNothing);
  });
}
