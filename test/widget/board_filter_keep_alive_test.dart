import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/di/providers.dart';
import 'package:work_nexus/core/domain/entities/workspace.dart';
import 'package:work_nexus/core/navigation/navigation_providers.dart';
import 'package:work_nexus/shared/board/presentation/providers/board_providers.dart';
import 'package:work_nexus/shared/board/presentation/widgets/board_filter_keep_alive.dart';

/// A board that watches the filter, as the sections in the viewport do.
class _Board extends ConsumerWidget {
  const _Board();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(filterStateProvider);
    return const SizedBox();
  }
}

void main() {
  /// Pumps a board that the viewport has put offstage, navigates to another
  /// board meanwhile, then brings the board back on screen.
  Future<void> navigateWhileOffstage(
    WidgetTester tester, {
    required bool keepAlive,
  }) async {
    final onScreen = ValueNotifier(false);
    addTearDown(onScreen.dispose);
    final board = ValueListenableBuilder<bool>(
      valueListenable: onScreen,
      builder: (_, enabled, _) =>
          TickerMode(enabled: enabled, child: const _Board()),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workspacesProvider.overrideWith(
            (ref) => Stream.value(const <Workspace>[]),
          ),
        ],
        child: MaterialApp(
          home: keepAlive ? BoardFilterKeepAlive(child: board) : board,
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(_Board)),
    );

    container.read(appNavProvider.notifier).selectAccount('acc');
    await tester.pump();
    onScreen.value = true;
    await tester.pump();
  }

  testWidgets('without it, the filter catches up mid-build and throws', (
    tester,
  ) async {
    await navigateWhileOffstage(tester, keepAlive: false);
    expect(tester.takeException(), isNotNull);
  });

  testWidgets('a board coming back on screen after navigation does not throw', (
    tester,
  ) async {
    await navigateWhileOffstage(tester, keepAlive: true);
    expect(tester.takeException(), isNull);
  });
}
