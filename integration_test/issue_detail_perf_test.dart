// On-device performance test for the issue (ticket detail) screen.
//
// Boots the real app against this machine's database and connected ZenTao
// account, re-syncs the account's assigned tickets (what the board's Refresh
// does, so bodies are normalized by the code under test), then opens a fixed
// mix of issues one by one — bugs, tickets with inline images, plain tickets:
// waits for the detail sync and the inline images, scrolls the description,
// switches to Comments & activity and back, closes. Frames are traced; the
// per-issue wall-clock timings are reported alongside. Read-only: no ticket is
// changed.
//
// Quit any running WorkNexus first (single instance), then: `make perf`.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:work_nexus/app/app.dart';
import 'package:work_nexus/core/database/database.dart';
import 'package:work_nexus/core/di/service_locator.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/navigation/navigation_providers.dart';
import 'package:work_nexus/data/local/mappers.dart';
import 'package:work_nexus/features/sync/data/sync_service.dart';
import 'package:work_nexus/features/task_detail/presentation/detail_panel.dart';
import 'package:work_nexus/features/task_detail/presentation/widgets/detail_tab_bar.dart';
import 'package:work_nexus/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('issue detail: open, load, scroll, switch tabs', (tester) async {
    await app.main(const []);
    await _wait(tester, const Duration(seconds: 2));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(WorkNexusApp)),
    );
    final db = getIt<AppDatabase>();

    final syncWatch = Stopwatch()..start();
    for (final row in await db.select(db.accounts).get()) {
      final account = accountFromRow(row);
      if (account.providerType != ProviderType.zentao) continue;
      await getIt<SyncService>().syncAccount(account);
    }
    final accountSyncMs = syncWatch.elapsedMilliseconds;

    final issues = await _pickIssues(db);
    expect(issues, isNotEmpty, reason: 'no ZenTao tickets: connect an account');

    container.read(chatOpenProvider.notifier).state = false;
    await _wait(tester, const Duration(seconds: 1));

    final timings = <Map<String, Object?>>[];
    await binding.traceAction(() async {
      for (final issue in issues) {
        timings.add(await _exercise(tester, container, issue));
      }
    }, reportKey: 'issue_detail_timeline');

    binding.reportData!['issue_detail_timings'] = <String, Object?>{
      'accountSyncMs': accountSyncMs,
      'issues': timings,
    };
  });
}

class _Issue {
  const _Issue(this.id, this.label, this.kind);
  final String id;
  final String label;
  final String kind;
}

/// Up to 3 bugs, 3 other tickets with inline images and 2 without, newest
/// first. Inline images are either expanded `file-read-` URLs or raw `{id.ext}`
/// placeholders, depending on the normalizer under test.
Future<List<_Issue>> _pickIssues(AppDatabase db) async {
  Future<List<_Issue>> query(String where, int limit, String kind) async {
    final rows = await db
        .customSelect(
          'SELECT id, external_type, external_key FROM tickets '
          "WHERE provider_type = 'zentao' AND ($where) "
          'ORDER BY updated_at DESC LIMIT $limit',
        )
        .get();
    return [
      for (final r in rows)
        _Issue(
          r.read<String>('id'),
          '${r.read<String>('external_type')} #'
          '${r.read<String>('external_key')}',
          kind,
        ),
    ];
  }

  const images = "body LIKE '%file-read-%' OR body LIKE '%({%}%'";
  final picked = <String, _Issue>{};
  for (final batch in [
    await query("external_type = 'Bug'", 3, 'bug'),
    await query("external_type <> 'Bug' AND ($images)", 3, 'images'),
    await query("external_type <> 'Bug' AND body NOT LIKE '%![%'", 2, 'plain'),
  ]) {
    for (final issue in batch) {
      picked.putIfAbsent(issue.id, () => issue);
    }
  }
  return picked.values.toList();
}

Future<Map<String, Object?>> _exercise(
  WidgetTester tester,
  ProviderContainer container,
  _Issue issue,
) async {
  Finder inPanel(Finder f) =>
      find.descendant(of: find.byType(DetailOverlay), matching: f);
  final syncBar = inPanel(find.byType(LinearProgressIndicator));
  final spinners = inPanel(find.byType(CircularProgressIndicator));

  final watch = Stopwatch()..start();
  container.read(openTicketIdProvider.notifier).open(issue.id);
  await tester.pump();
  final firstFrameMs = watch.elapsedMilliseconds;

  // The detail sync shows a 2px bar under the tab strip while it runs.
  await _pumpUntil(
    tester,
    () => syncBar.evaluate().isNotEmpty,
    timeout: const Duration(milliseconds: 500),
  );
  final detailDone = await _pumpUntil(tester, () => syncBar.evaluate().isEmpty);
  final detailMs = watch.elapsedMilliseconds;

  // Inline images show a spinner each until their bytes arrive.
  final imageSpinners = spinners.evaluate().length;
  final imagesDone = await _pumpUntil(
    tester,
    () => spinners.evaluate().isEmpty,
    timeout: const Duration(seconds: 20),
  );
  final imagesMs = watch.elapsedMilliseconds;

  final body = inPanel(
    find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    ),
  );
  if (body.evaluate().isNotEmpty) {
    for (var i = 0; i < 3; i++) {
      await tester.drag(body.first, const Offset(0, -400));
      await _wait(tester, const Duration(milliseconds: 300));
    }
    await tester.drag(body.first, const Offset(0, 1200));
    await _wait(tester, const Duration(milliseconds: 300));
  }

  final tabs = find.descendant(
    of: find.byType(DetailTabBar),
    matching: find.byType(Text),
  );
  final comments = find.descendant(
    of: find.byType(DetailTabBar),
    matching: find.textContaining(' & '),
  );
  if (comments.evaluate().isNotEmpty) {
    await tester.tap(comments.first);
    await _wait(tester, const Duration(milliseconds: 600));
    await tester.tap(tabs.first);
    await _wait(tester, const Duration(milliseconds: 600));
  }

  container.read(openTicketIdProvider.notifier).close();
  await _wait(tester, const Duration(milliseconds: 500));

  return {
    'issue': issue.label,
    'kind': issue.kind,
    'firstFrameMs': firstFrameMs,
    'detailSyncMs': detailMs,
    'detailSyncTimedOut': !detailDone,
    'imageSpinners': imageSpinners,
    'imagesLoadedMs': imagesMs,
    'imagesTimedOut': !imagesDone,
  };
}

/// Pumps frames until [done] or [timeout]; returns whether [done] was reached.
Future<bool> _pumpUntil(
  WidgetTester tester,
  bool Function() done, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final watch = Stopwatch()..start();
  while (!done()) {
    if (watch.elapsed > timeout) return false;
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 16));
  }
  return true;
}

/// Keeps pumping frames (real time passes in the live binding) for [duration].
Future<void> _wait(WidgetTester tester, Duration duration) =>
    _pumpUntil(tester, () => false, timeout: duration);
