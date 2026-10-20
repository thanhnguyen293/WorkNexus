import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/app/di/service_locator.dart';
import 'package:work_nexus/core/domain/adapters/provider_adapter.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/util/cancel_signal.dart';
import 'package:work_nexus/core/widgets/app_icon_button.dart';
import 'package:work_nexus/l10n/app_localizations.dart';
import 'package:work_nexus/tools/zentao/domain/repositories/zentao_view_pages.dart';
import 'package:work_nexus/tools/zentao/presentation/providers/zentao_board_providers.dart';
import 'package:work_nexus/tools/zentao/presentation/widgets/zentao_board_refresh_button.dart';

class _MockViewPages extends Mock implements ZenTaoViewPages {}

const _product = ProviderProduct(
  id: '4',
  name: 'VN_Socialfi',
  accountId: 'zentao',
);

const _execution = ProviderExecution(
  id: '9',
  name: 'Sprint 9',
  projectId: '2',
  accountId: 'zentao',
);

const _emptyPage = Ok(ViewPage(tickets: [], total: 0, hasMore: false));

/// The bug and task boards' Refresh: a tap starts every view over from its
/// first page, and the button spins while the board is fetching.
void main() {
  late _MockViewPages sync;

  setUpAll(() => registerFallbackValue(CancelSignal()));

  setUp(() async {
    sync = _MockViewPages();
    await getIt.reset();
    getIt.registerSingleton<ZenTaoViewPages>(sync);
  });

  tearDown(getIt.reset);

  void answerBugPages(Future<Result<ViewPage>> Function() page) => when(
    () => sync.syncProductBugsPage(
      accountId: any(named: 'accountId'),
      productId: any(named: 'productId'),
      browseType: any(named: 'browseType'),
      page: any(named: 'page'),
      limit: any(named: 'limit'),
      cancel: any(named: 'cancel'),
    ),
  ).thenAnswer((_) => page());

  Future<ProviderContainer> pumpButton(
    WidgetTester tester, {
    required bool bugs,
  }) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    if (bugs) {
      container.read(selectedZenTaoProductProvider.notifier).select(_product);
    } else {
      container
          .read(selectedZenTaoExecutionProvider.notifier)
          .select(_execution);
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          theme: buildAppTheme(
            variant: AppThemeVariant.light,
            surface: SurfaceStyle.outline,
            density: AppDensity.comfortable,
          ),
          home: Scaffold(body: ZenTaoBoardRefreshButton(bugs: bugs)),
        ),
      ),
    );
    await tester.pump();
    return container;
  }

  bool spinning(WidgetTester tester) =>
      tester.widget<AppIconButton>(find.byType(AppIconButton)).isLoading;

  testWidgets('refreshing the bug board reloads every view from page 1', (
    tester,
  ) async {
    answerBugPages(() async => _emptyPage);
    await pumpButton(tester, bugs: true);
    expect(spinning(tester), isFalse);

    await tester.tap(find.byType(AppIconButton));
    await tester.pump();
    await tester.pump();

    for (final view in ['unconfirmed', 'unresolved', 'toclosed']) {
      verify(
        () => sync.syncProductBugsPage(
          accountId: 'zentao',
          productId: '4',
          browseType: view,
          page: 1,
          limit: any(named: 'limit'),
          cancel: any(named: 'cancel'),
        ),
      ).called(2);
    }
  });

  testWidgets('spins while the bug board is fetching, then stops', (
    tester,
  ) async {
    final page = Completer<Result<ViewPage>>();
    answerBugPages(() => page.future);
    await pumpButton(tester, bugs: true);
    expect(spinning(tester), isTrue);

    page.complete(_emptyPage);
    await tester.pump();
    await tester.pump();
    expect(spinning(tester), isFalse);
  });

  testWidgets('refreshing the task board reloads every status view from '
      'page 1', (tester) async {
    when(
      () => sync.syncExecutionTasksPage(
        accountId: any(named: 'accountId'),
        executionId: any(named: 'executionId'),
        browseType: any(named: 'browseType'),
        page: any(named: 'page'),
        limit: any(named: 'limit'),
        cancel: any(named: 'cancel'),
      ),
    ).thenAnswer((_) async => _emptyPage);
    await pumpButton(tester, bugs: false);

    await tester.tap(find.byType(AppIconButton));
    await tester.pump();
    await tester.pump();

    for (final view in ['wait', 'doing', 'pause', 'done', 'closed', 'cancel']) {
      verify(
        () => sync.syncExecutionTasksPage(
          accountId: 'zentao',
          executionId: '9',
          browseType: view,
          page: 1,
          limit: any(named: 'limit'),
          cancel: any(named: 'cancel'),
        ),
      ).called(2);
    }
  });
}
