import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/widgets/rich_text_editor.dart';
import 'package:work_nexus/features/task_detail/presentation/widgets/comment_composer.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

Ticket _ticket(ProviderType type) => Ticket(
  id: 'x:1',
  accountId: 'x',
  projectId: 'x:P',
  providerType: type,
  externalKey: '1',
  title: 't',
  body: 'b',
  priority: Priority.medium,
  status: UnifiedStatus.todo,
  providerStatus: 'open',
  sourceHash: 'h',
);

void main() {
  Future<void> pump(WidgetTester tester, ProviderType type) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildAppTheme(
            variant: AppThemeVariant.dark,
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
              child: CommentComposer(ticket: _ticket(type)),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a ZenTao comment is written in the rich editor (images)', (
    tester,
  ) async {
    await pump(tester, ProviderType.zentao);
    expect(find.byType(RichTextEditor), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('a GitHub comment stays a plain Markdown field', (tester) async {
    await pump(tester, ProviderType.github);
    expect(find.byType(RichTextEditor), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
  });
}
