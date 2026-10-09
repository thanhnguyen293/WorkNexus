import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/di/providers.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/settings/app_settings.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/task_detail/presentation/widgets/translation_tab.dart';
import 'package:work_nexus/features/translation/presentation/translation_providers.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

/// Regression: the failed-translation banner used to claim "OpenCode timed out"
/// for *every* failure, so a model/auth problem (the common case) was reported
/// as a timeout and retrying could never help. It must show what actually broke.
const _ticket = Ticket(
  id: 'zentao:bug:6041',
  accountId: 'zentao',
  projectId: '4',
  providerType: ProviderType.zentao,
  externalKey: '6041',
  externalType: 'bug',
  title: 'Restored post is missing from Feed',
  body: 'Steps to reproduce…',
  priority: Priority.high,
  status: UnifiedStatus.todo,
  providerStatus: 'active',
  sourceHash: 'hash',
);

/// A controller parked in the failed state for [_ticket].
class _FailedTranslationController extends TranslationController {
  _FailedTranslationController(this.message);

  final String message;

  @override
  Map<String, TranslationUiState> build() => {
    _ticket.id: TranslationUiState(error: message),
  };
}

void main() {
  Future<void> pumpTab(WidgetTester tester, String message) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ticketsProvider.overrideWith((ref) => Stream.value(const [_ticket])),
          workspacesProvider.overrideWith((ref) => Stream.value(const [])),
          accountsProvider.overrideWith((ref) => Stream.value(const [])),
          projectsProvider.overrideWith((ref) => Stream.value(const [])),
          translationRecordProvider(_ticket.id)
              .overrideWith((ref) => Stream.value(null)),
          translationControllerProvider.overrideWith(
            () => _FailedTranslationController(message),
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
          home: const Scaffold(
            body: TranslationTab(ticket: _ticket, layout: DetailLayout.twoPane),
          ),
        ),
      ),
    );
    // One frame for the overridden streams, one to render their data.
    await tester.pump();
    await tester.pump();
  }

  testWidgets('the banner quotes the failure instead of blaming a timeout', (
    tester,
  ) async {
    await pumpTab(
      tester,
      'OpenCode exited 1: Error: this model requires explicit opt in',
    );

    expect(
      find.textContaining('this model requires explicit opt in'),
      findsOneWidget,
    );
    expect(find.textContaining('timed out'), findsNothing);
  });

  testWidgets('a failure with no detail still reports the failure', (
    tester,
  ) async {
    await pumpTab(tester, '');

    expect(find.textContaining('Translation failed'), findsOneWidget);
  });
}
